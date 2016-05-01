//light properties
//float3 lPos <string uiname="Light Position";> = {0, 5, -2};       //light position in world space
//float lAtt0 <String uiname="Light Attenuation 0"; float uimin=0.0;> = 0;
//float lAtt1 <String uiname="Light Attenuation 1"; float uimin=0.0;> = 0.3;
//float lAtt2 <String uiname="Light Attenuation 2"; float uimin=0.0;> = 0;
//float4 lAmb  <bool color=true; String uiname="Ambient Color";>  = {0.15, 0.15, 0.15, 1};
//float4 lDiff <bool color=true; String uiname="Diffuse Color";>  = {0.85, 0.85, 0.85, 1};
//float4 lSpec <bool color=true; String uiname="Specular Color";> = {0.35, 0.35, 0.35, 1};
//float lPowerSpot <String uiname="Power"; float uimin=0.0;> = 25.0;     //shininess of specular highlight
//float lRange1 <String uiname="Light Range"; float uimin=0.0;> = 10.0;




//phong point function
float4 PhongPointSpot(float3 PosW, float3 NormV, float3 ViewDirV, float3 LightDirV, float3 lightPos, float lAtt0,
				  float lAtt1, float lAtt2, float4 lDiff, float4 lSpec, float specIntensity, float2 projectTexCoord, float4 projectionColor)
{

    float d = distance(PosW, lightPos);
    float atten = 0;
    float4 result;

    //compute attenuation only if vertex within lightrange
    if (d<lRange)
    {
       atten = 1/(saturate(lAtt0) + saturate(lAtt1) * d + saturate(lAtt2) * pow(d, 2));
    }


    //halfvector
    float3 H = normalize(ViewDirV + LightDirV);

    //compute blinn lighting
    float4 shades = lit(dot(NormV, LightDirV), dot(NormV, H), lPower);

    float4 diff = lDiff * shades.y * atten;
    diff.a = 1;

    //reflection vector (view space)
    float3 R = normalize(2 * dot(NormV, LightDirV) * NormV - LightDirV);

    //normalized view direction (view space)
    float3 V = normalize(ViewDirV);

    //calculate specular light
    float4 spec = pow(max(dot(R, V),0), lPower*.2) * lSpec;
	
    spec *= specIntensity;

    if((saturate(projectTexCoord.x) == projectTexCoord.x) && (saturate(projectTexCoord.y) == projectTexCoord.y))
    {
        // Sample the color value from the projection texture using the sampler at the projected texture coordinate location.
       

        // Set the output color of this pixel to the projection texture overriding the regular color value.
       result =  saturate( diff + spec)*projectionColor*100;

        
    }else{
        result = 0;
    }


    return result;
}
