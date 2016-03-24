//@author: vvvv group
//@help: basic pixel based lightning with point light
//@tags: shading, blinn
//@credits:

// -----------------------------------------------------------------------------
// PARAMETERS:
// -----------------------------------------------------------------------------

//transforms
float4x4 tW: WORLD;        //the models world matrix
float4x4 tV: VIEW;         //view matrix as set via Renderer (DX9)
float4x4 tWV: WORLDVIEW;
float4x4 tWVP: WORLDVIEWPROJECTION;
float4x4 tP: PROJECTION;   //projection matrix as set via Renderer (DX9)
float4x4 tWIT: WORLDINVERSETRANSPOSE;

//float lAtt0 <String uiname="Light Attenuation 0"; float uimin=0.0;> = 0;
//float3 lPos <string uiname="Light Position";> = {0, 5, -2};       //light position in world space


StructuredBuffer <int> lightType <string uiname="Directional/Point";>;

StructuredBuffer <float3> lPos <string uiname="lPos";>;

StructuredBuffer <float> lAtt0 <string uiname="lAtt0";>;
StructuredBuffer <float> lAtt1 <string uiname="lAtt1";>;
StructuredBuffer <float> lAtt2 <string uiname="lAtt2";>;


StructuredBuffer <float4> lAmb <string uiname="Ambient Color";>;
StructuredBuffer <float4> lDiff <string uiname="Diffuse Color";>;
StructuredBuffer <float4> lSpec <string uiname="Specular Color";>;


int lightCount <string uiname="lightCount";>;

#include "PhongPoint.fxh"
#include "PhongDirectional.fxh"

Texture2D texture2d <string uiname="Texture"; >;
Texture2D specTex <string uiname="SpecularMap"; >;
Texture2D lightMap <string uiname="LightMap"; >;
 

SamplerState g_samLinear
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};

float4x4 tTex <bool uvspace=true; string uiname="Texture Transform";>;
float4x4 tColor <string uiname="Color Transform";>;

struct vs2ps
{
    float4 PosWVP: SV_POSITION;
    float4 TexCd : TEXCOORD0;
    //float3 LightDirV: TEXCOORD1;
    float3 NormV: TEXCOORD2;
    float3 ViewDirV: TEXCOORD3;
    float3 PosW: TEXCOORD4;
};

// -----------------------------------------------------------------------------
// VERTEXSHADERS
// -----------------------------------------------------------------------------

vs2ps VS(
    float4 PosO: POSITION,
    float3 NormO: NORMAL,
    float4 TexCd : TEXCOORD0)
{
    //inititalize all fields of output struct with 0
    vs2ps Out = (vs2ps)0;

    Out.PosW = mul(PosO, tW).xyz;

    //inverse light direction in view space
    //float3 LightDirW = normalize(lPos[0] - Out.PosW);
   // Out.LightDirV = mul(float4(LightDirW,0.0f), tV).xyz;
    
    //normal in view space
    Out.NormV = normalize(mul(mul(NormO, (float3x3)tWIT),(float3x3)tV).xyz);

    //position (projected)
    Out.PosWVP  = mul(PosO, tWVP);
    Out.TexCd = mul(TexCd, tTex);
    Out.ViewDirV = -normalize(mul(PosO, tWV).xyz);
    return Out;
}

// -----------------------------------------------------------------------------
// PIXELSHADERS:
// -----------------------------------------------------------------------------
float Alpha <float uimin=0.0; float uimax=1.0;> = 1;

float4 PS(vs2ps In): SV_Target
{	
	float2 projectTexCoord;
	float4 projectionColor;
	float4 specIntensity = specTex.Sample(g_samLinear, In.TexCd.xy);
	
	
	float4 col = texture2d.Sample(g_samLinear, In.TexCd.xy);
	float3 newCol;
	float3 LightDirW;
	float3 LightDirV;
	for(int i = 0; i< lightCount; i++){
		if(lightType[i] == 0){
			LightDirV = normalize(-mul(lPos[i], tV));
			newCol += PhongDirectional(In.NormV, In.ViewDirV, LightDirV, lAmb[i], lDiff[i], lSpec[i],specIntensity).rgb;
		} else {
			LightDirW = normalize(lPos[i] - In.PosW);
			LightDirV = mul(float4(LightDirW,0.0f), tV).xyz;
	  		newCol += PhongPoint(In.PosW, In.NormV, In.ViewDirV, LightDirV, lPos[i], lAtt0[i],lAtt1[i],lAtt2[i], lAmb[i], lDiff[i], lSpec[i],specIntensity).rgb;
		
			 projectTexCoord.x =  In.PosWVP.x / In.PosWVP.w / 2.0f + 0.5f;
   			 projectTexCoord.y = -In.PosWVP.y / In.PosWVP.w / 2.0f + 0.5f;
			
//			 if((saturate(projectTexCoord.x) == projectTexCoord.x) && (saturate(projectTexCoord.y) == projectTexCoord.y))
//				    {
				        // Sample the color value from the projection texture using the sampler at the projected texture coordinate location.
				        projectionColor = lightMap.Sample(g_samLinear, projectTexCoord);
			
				        // Set the output color of this pixel to the projection texture overriding the regular color value.
				        newCol.xyz += projectionColor.xyz;
//				    }
		}
		
	}
    
	col.rgb *= newCol;
	col.a *= Alpha;
    return mul(col, tColor);
}


// -----------------------------------------------------------------------------
// TECHNIQUES:
// -----------------------------------------------------------------------------
technique10 TPhongPoint
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_4_0, PS() ) );
	}
}

