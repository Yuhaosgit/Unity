#ifndef CUSTOM_FUNCIONS
#define CUSTOM_FUNCIONS

#define PI 3.14159

float3 Fresnel(float3 normal, float3 viewDir, float3 F0, float exponent){
	return F0 + (1-F0) * pow(1 - saturate(dot(normal,viewDir)), exponent);
}

//Waves
struct WaveNormals{
    float3 normal;
    float3 tangent;
    float3 bitangent;
};

float DerivativesHeightX(float3 positionOS, float amplitude, float speed, float waveLength,float2 direction)
{
    float t = _Time.y;
    float w = 2 / waveLength;
    float phase = speed * w;
    return w * direction.x * amplitude * cos(dot(direction, positionOS.xz) * w + t * phase);
}

float DerivativesHeightY(float3 positionOS, float amplitude, float speed, float waveLength,float2 direction)
{
    float t = _Time.y;
    float w = 2 / waveLength;
    float phase = speed * w;
    return w * direction.y * amplitude * cos(dot(direction, positionOS.xz) * w + t * phase);
}

WaveNormals CalculateNormals(float3 positionOS, float amplitude, float speed, float waveLength, float2 direction){
    WaveNormals waveNormals;

    waveNormals.tangent =
    float3(1,DerivativesHeightY(positionOS, amplitude, speed, waveLength, direction),0);

    waveNormals.bitangent =
    float3(0,DerivativesHeightX(positionOS, amplitude, speed, waveLength, direction),1);

    waveNormals.normal = normalize(cross(waveNormals.bitangent,waveNormals.tangent));
    return waveNormals;
}

WaveNormals GetCircularNormals(float3 positionOS, float amplitude, float speed, float waveLength){
    float2 direction = (-positionOS.xz) / (length(positionOS.xz) + 0.001);
    return CalculateNormals(positionOS,amplitude,speed,waveLength,direction);
}

WaveNormals GetSinusoidNormals(float3 positionOS, float amplitude, float speed, float waveLength, float2 direction){
    direction = normalize(direction);
    return CalculateNormals(positionOS,amplitude,speed,waveLength,direction);
}

float SinWaveFunction(float3 positionOS, float amplitude, float speed, float waveLength, float2 direction){
    float w = 2 * PI/ waveLength;
    float phase = speed * w;
    float H = amplitude * sin(dot(positionOS.xz, direction) * w + _Time.y * phase);
    return H;
}

float SinusoidsWave(float3 positionOS, float amplitude, float speed, float waveLength, float2 direction)
{
    direction = normalize(direction);
    return SinWaveFunction(positionOS, amplitude, speed, waveLength, direction);
}

float CircularWave(float3 positionOS, float amplitude, float speed, float waveLength)
{
    float2 direction = (-positionOS.xz) / (length(positionOS.xz) + 0.001);
    return SinWaveFunction(positionOS, amplitude, speed, waveLength, direction);
}

//
WaveNormals NormalInitialization(){
    WaveNormals normals;

    normals.normal = float3(0,0,0);
    normals.tangent = float3(0,0,0);
    normals.bitangent = float3(0,0,0);

    return normals;
}

WaveNormals GetGerstnerNormals(WaveNormals normals){
    normals.bitangent.x =  - normals.bitangent.x;
    normals.bitangent.z =1 -normals.bitangent.z;

    normals.tangent.x =  1-normals.tangent.x;
    normals.tangent.z =  - normals.tangent.z;

    normals.normal = normalize(cross(normals.bitangent,normals.tangent));
    return normals;
}

float3 Gerstner(float3 positionOS, float stepness, float amplitude, float speed, float waveLength, float2 direction, float waveNumber ,inout WaveNormals normals){
    direction = normalize(direction);
    float w = sqrt(2 * 9.8 * PI/ waveLength);
    float wave = (w*dot(direction, positionOS.xz) + speed*w*_Time.y);
    float Q = stepness/(w*amplitude*waveNumber);
    
    positionOS.xz = positionOS.xz + Q*amplitude*direction*cos(wave);
    positionOS.y = amplitude*sin(wave);

    //normal calculation
    float WA = w*amplitude;

    normals.bitangent.z += Q * (direction.x * direction.x) * WA *sin(wave);
    normals.bitangent.x += Q * (direction.x * direction.y) * WA *sin(wave);
    normals.bitangent.y += direction.x * WA *cos(wave);

    normals.tangent.z += Q * (direction.x * direction.y) * WA *sin(wave);
    normals.tangent.x += Q * (direction.y * direction.y) * WA *sin(wave);
    normals.tangent.y += direction.y * WA *cos(wave);

    return positionOS;
}

#endif