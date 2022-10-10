Shader "Custom/Water"
{
    Properties
    {
        _MainNormal ("Main Normal", 2D) = "white" {}
        _SecondNormal ("Second Normal", 2D) = "white" {}
        _Color ("Deep Color", Color) = (39,57,87,197)
        _Speed("Speed", Range(0.0,1.0)) = 0.5
        _NormalStrenght("Normal Strenght",float) = 0.4
        _FresnelExponent("Fresnel Exponent",range(0.5,5)) = 1.0

        _Amplitude("Amplitude",range(0,100)) = 0.01
        _WaveSpeed("WaveSpeed",range(0,100)) = 0.01
        _WaveLength("WaveLength",range(0,1000)) = 0.01
        _WaveStepness("WaveStepness",range(0,1)) = 0.1
        [ShowAsVector2] _WaveDirection("WaveDirection",Vector) = (1,1,0,0)

        _Refraction("Refraction",float) = 30
        _Density("Density",float) = 0.15
        _LambertRatio("Lamber Ratio",range(0,1)) = 0.1

    }
    SubShader
    {
        Tags {
        "RenderType" = "TransParent"
        "Queue" = "TransParent"
        "RenderPipeline" = "UniversalPipeline" 
        "IgnoreProjector" = "True"
        }
        Pass{

        Blend SrcAlpha OneMinusSrcAlpha

        HLSLPROGRAM

        #pragma vertex Vert
        #pragma fragment Frag
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Functions.hlsl"
        #define REQUIRE_DEPTH_TEXTURE	

        CBUFFER_START(UnityPerMaterial)
        float4 _MainNormal_ST;
        float4 _SecondNormal_ST;
        float4 _Color;
        float _Speed;
        float _NormalStrenght;
        float _FresnelExponent;

        float _Amplitude;
        float _WaveSpeed;
        float _WaveLength;
        float _WaveStepness;
        float4 _WaveDirection;

        float _Refraction;
        float _Density;
        float _LambertRatio;
        CBUFFER_END

        TEXTURE2D(_MainNormal);
        SAMPLER(sampler_MainNormal);
        TEXTURE2D(_SecondNormal);
        SAMPLER(sampler_SecondNormal);

        struct AttributeToVertex{
            float4 position:POSITION;
            float3 normal:NORMAL;
            float4 tangent:TANGENT;
            float2 UVCoordinate:TEXCOORD;
        };
        
        struct VertexToFragment{
            float4 position:SV_POSITION;
            float3 normal:TEXCOORD0;
            float3 tangent:TEXCOORD1;
            float3 bitangent:TEXCOORD2;
            float2 mainUV : TEXCOORD3;
            float2 secondUV : TEXCOORD5;
            float4 screenPos:TEXCOORD6;
            float3 worldPosition:TEXCOORD7;
        };

        VertexToFragment Vert(AttributeToVertex input){
            VertexToFragment output;

            VertexPositionInputs vertexInputs;
            VertexNormalInputs normalInputs;

            //wave
            WaveNormals waveNormals = NormalInitialization();

            input.position.xyz = Gerstner(input.position,_WaveStepness, _Amplitude,_WaveSpeed,_WaveLength, _WaveDirection.xz, 3, waveNormals);
            input.position.xyz = Gerstner(input.position,_WaveStepness*0.8, _Amplitude*0.94,_WaveSpeed*1.21,_WaveLength*0.89, _WaveDirection.xz*float2(0,-1), 3, waveNormals);
            input.position.xyz = Gerstner(input.position,_WaveStepness*0.9, _Amplitude*1.1,_WaveSpeed*1.01,_WaveLength*1.29, _WaveDirection.xz*float2(-1,0), 3, waveNormals);

            waveNormals = GetGerstnerNormals(waveNormals);

            output.normal = waveNormals.normal;
            output.tangent = waveNormals.tangent;
            output.bitangent = waveNormals.bitangent;
            
            vertexInputs = GetVertexPositionInputs(input.position.xyz);

            output.position = vertexInputs.positionCS;
            output.screenPos = ComputeScreenPos(output.position);
            output.worldPosition = vertexInputs.positionWS;

            output.mainUV = TRANSFORM_TEX(input.UVCoordinate,_MainNormal);
            output.secondUV = TRANSFORM_TEX(input.UVCoordinate,_SecondNormal);

            return output;
        }

        float3 FlowUV(float2 UV, float2 direction, float2 jump, float time, float phase){
            float progressTime = frac(time + phase);
            float3 flow;
            flow.xy = UV - direction * progressTime;
            flow.xy *= 0.2;
            flow.xy += phase;
            flow.xy += (time-progressTime)*jump;
            flow.z = 1 - abs(1 - 2*progressTime);
            return flow;
        }

        float4 Frag(VertexToFragment input):SV_TARGET{
            //return float4(input.normal,1);
            //water depth
            input.screenPos.xy /= input.screenPos.w;

            float depth = SampleSceneDepth(input.screenPos.xy);
            float deepZ = LinearEyeDepth(depth,_ZBufferParams);

            float3 worldPos = ComputeWorldSpacePosition(input.screenPos.xy,depth,UNITY_MATRIX_I_VP);

            float depthDiffernce = (input.worldPosition.y - worldPos.y);
            //Flow map
            float3x3 TBN = float3x3(input.tangent, input.bitangent, input.normal); 
            float4 flowDirect = SAMPLE_TEXTURE2D(_MainNormal,sampler_MainNormal,input.mainUV);
            flowDirect*= _NormalStrenght;

            float time = _Time.y*_Speed + flowDirect.a;
            float3 flowUVA = FlowUV(input.mainUV, flowDirect.xy, float2(-0.1,0.1), time, 0);
            float3 flowUVB = FlowUV(input.mainUV, flowDirect.xy, float2(-0.1,0.1), time, 0.5);

            float3 normalTexA = UnpackNormal(SAMPLE_TEXTURE2D(_SecondNormal,sampler_SecondNormal,flowUVA.xy))*flowUVA.z;
            float3 normalTexB = UnpackNormal(SAMPLE_TEXTURE2D(_SecondNormal,sampler_SecondNormal,flowUVB.xy))*flowUVB.z;
            normalTexA = mul(TBN,normalTexA);
            normalTexB = mul(TBN,normalTexB);

            float3 normalTex = SafeNormalize(normalTexA + normalTexB);
            float3 normal = normalize(float3(0,1,0));

            //Lighting
            Light mainLight = GetMainLight();
            float3 lightLambert = LightingLambert(mainLight.color,mainLight.direction,normalTex);
            float3 viewDir = normalize(_WorldSpaceCameraPos - input.worldPosition);

            float3 lightSpecular = 
            LightingSpecular(mainLight.color,mainLight.direction,normalTex,viewDir,float4(1,1,1,1),60);
            float3 fresnel = Fresnel(normalTex,viewDir,float3(0.02,0.02,0.02),_FresnelExponent);

            //reflection
            float3 reflectDirWS = reflect(-viewDir,normalTex);
            float4 _CubeMapColor = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectDirWS,0);

            //refraction
            float3 opaqueColor = SampleSceneColor(input.screenPos.xy+normalTex.xz/_Refraction);
            float3 fresnelColor = lerp(opaqueColor,_CubeMapColor,saturate(fresnel));
            
            float fogFactor = exp2(-_Density*depthDiffernce);
	        float3 result = lerp(_Color.xyz, fresnelColor, fogFactor) * (1-_Color.a);
            result = lerp(lightLambert,result,1 -_LambertRatio);
            result += lightSpecular*0.33;

            return float4(result,1);
        }
        ENDHLSL
        }
    }
}