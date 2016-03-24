//@author: schnellebuntebilder
//@help: basic pixel based lightning with point light
//@tags: shading, blinn
//@credits: Vux, Dottore, Catweasel

// -----------------------------------------------------------------------------
// PARAMETERS:
// -----------------------------------------------------------------------------


cbuffer cbPerRender : register( b0 )
{
	float4x4 tP: PROJECTION;   //projection matrix as set via Renderer
	float4x4 tV: VIEW;         //view matrix as set via Renderer
	float2 KrMin <String uiname="Fresnel Min";float uimin=0.0; float uimax=1;> = 0.002 ;
	float2 Kr <String uiname="Fresnel Max";float uimin=0.0; float uimax=6.0;> = 0.5 ;
	float2 FresExp <String uiname="Fresnel Exp";float uimin=0.0; float uimax=30;> = 5 ;
	float3 camPos;
	float4 RimColor <bool color = true; string uiname="Rim Color";>  = { 1.0f,1.0f,1.0f,1.0f };
	float4 Color <bool color = true; string uiname="Color Overlay";>  = { 1.0f,1.0f,1.0f,1.0f };
};
 
cbuffer cbPerObject : register (b1)
{	

	//transforms
	float4x4 tW: WORLD;        //the models world matrix
	float4x4 tWV: WORLDVIEW;
	float4x4 tWVP: WORLDVIEWPROJECTION;
	float4x4 tWIT: WORLDINVERSETRANSPOSE;

	int lightCount <string uiname="lightCount";>;
	
	float lightMapFade = 1;
	float bumpy = 1;
	float reflective = 1;
	int reflectMode <string uiname="ReflectionMode: Mul/Add"; int uimin=0.0; int uimax=1.0;> = 0;
	int diffuseMode <string uiname="DiffuseAffect: Reflection/Specular/Both"; int uimin=0.0; int uimax=2.0;> = 0;
};
	
	StructuredBuffer <float4x4> texTransforms <string uiname="tColor,tSpec,tDiffuse,tNormal";>;
	StructuredBuffer <float4x4> LightVP <string uiname="LightView";>;
	StructuredBuffer <float> spotRange <string uiname="spotRange";>;
	StructuredBuffer <int> lightType <string uiname="Directional/Point/Spot";>;	
	StructuredBuffer <float3> lPos <string uiname="lPos";>;

	StructuredBuffer <float> lAtt0 <string uiname="lAtt0";>;
	StructuredBuffer <float> lAtt1 <string uiname="lAtt1";>;
	StructuredBuffer <float> lAtt2 <string uiname="lAtt2";>;

	StructuredBuffer <float4> lAmb <string uiname="Ambient Color";>;
	StructuredBuffer <float4> lDiff <string uiname="Diffuse Color";>;
	StructuredBuffer <float4> lSpec <string uiname="Specular Color";>;

	Texture2D texture2d <string uiname="Texture"; >;
	Texture2D specTex <string uiname="SpecularMap"; >;
	Texture2D normalTex <string uiname="NormalMap"; >;
	Texture2D diffuseTex <string uiname="DiffuseMap"; >;
	TextureCube cubeTex <string uiname="CubeMap"; >;
	Texture2DArray lightMap <string uiname="LightMap"; >;


#include "PhongPoint.fxh"
#include "PhongPointSpot.fxh"
#include "PhongDirectional.fxh"

SamplerState g_samLinear
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};

struct vs2ps
{
    float4 PosWVP: SV_POSITION;
    float4 TexCd : TEXCOORD0;
	float4 PosO: TEXCOORD1;
    float3 NormV: TEXCOORD2;
	float3 ViewDirV: TEXCOORD3;
	float3 PosW: TEXCOORD4;
	float3 NormW : TEXCOORD5;

};

// -----------------------------------------------------------------------------
// VERTEXSHADERS
// -----------------------------------------------------------------------------

vs2ps VS(
    float4 PosO: POSITION,
    float3 NormO: NORMAL,
    float4 TexCd : TEXCOORD0

)
{
    //inititalize all fields of output struct with 0
    vs2ps Out = (vs2ps)0;

    Out.PosW = mul(PosO, tW).xyz;
	Out.PosO = PosO;
	
    Out.NormW = mul(NormO, tW);

    //normal in view space
    Out.NormV = normalize(mul(mul(NormO, (float3x3)tWIT),(float3x3)tV).xyz);


//	position (projected)
    Out.PosWVP  = mul(PosO, tWVP);

//    Out.TexCd = mul(TexCd, tTex);
	Out.TexCd = TexCd;
    Out.ViewDirV = -normalize(mul(PosO, tWV).xyz);
    return Out;
}

// -----------------------------------------------------------------------------
// PIXELSHADERS:
// -----------------------------------------------------------------------------
float Alpha <float uimin=0.0; float uimax=1.0;> = 1;

float4 PS(vs2ps In): SV_Target
{	
	
	float3 LightDirW;
	float3 LightDirV;
	float4 viewPosition;
	float2 projectTexCoord;
	float4 projectionColor;
	
	
	float4 col = texture2d.Sample(g_samLinear, mul(In.TexCd.xy,texTransforms[0]));
	float4 specIntensity = specTex.Sample(g_samLinear, mul(In.TexCd.xy,texTransforms[1]));
	float4 diffuse = diffuseTex.Sample(g_samLinear, mul(In.TexCd.xy,texTransforms[2]));
	
	if(diffuseMode == 1 || diffuseMode ==2){
		specIntensity *= diffuse;
	}
	
	
	float3 newCol;

	float3 Nn = normalize(In.NormW);
	
	
// Reflection and RimLight
	float3 Vn = normalize(camPos - In.PosW);
	
	float3 reflVect = -reflect(Vn,Nn);


	float vdn = dot(Vn,In.NormW);
   	float4 fresRim = KrMin.x + (Kr.x-KrMin.x) * pow(1-abs(vdn),FresExp.x);
	float4 fresRefl = KrMin.y + (Kr.y-KrMin.y) * pow(1-abs(vdn),FresExp.y);

	

	
	uint d,textureCount;
	lightMap.GetDimensions(d,d,textureCount);
	
	
	for(int i = 0; i< lightCount; i++){
		float3 lightToObject = lPos[i] - In.PosW;
		switch (lightType[i]){
			case 0:
				LightDirV = normalize(-mul(lPos[i], tV));
				newCol += PhongDirectional(In.NormV, In.ViewDirV, LightDirV, lAmb[i], lDiff[i], lSpec[i],specIntensity).rgb;
				break;
			case 1:

				if(length(lightToObject) < spotRange[i]){
					viewPosition = mul(In.PosO, tW);
					viewPosition = mul(viewPosition, LightVP[i]);
					
					projectTexCoord.x =  viewPosition.x / viewPosition.w / 2.0f + 0.5f;
		   			projectTexCoord.y = -viewPosition.y / viewPosition.w / 2.0f + 0.5f;
					
					
					float3 coords = float3(projectTexCoord, i % textureCount);	//make sure Instance ID buffer is in floats
					projectionColor = lightMap.Sample(g_samLinear, coords, 0 );
					projectionColor *= saturate(1/(viewPosition.z*lightMapFade));					
					LightDirW = normalize(lightToObject);
					LightDirV = mul(float4(LightDirW,0.0f), tV).xyz;
			  		newCol += PhongPointSpot(In.PosW, In.NormV, In.ViewDirV, LightDirV, lPos[i], lAtt0[i],lAtt1[i],lAtt2[i], lAmb[i], lDiff[i], lSpec[i],specIntensity, projectTexCoord,projectionColor).rgb;
					
				}
			
				break;
			
			case 2:
				
				if(length(lightToObject) < spotRange[i]){	
					
					LightDirW = normalize(lightToObject);
					LightDirV = mul(float4(LightDirW,0.0f), tV).xyz;
			  		newCol += PhongPoint(In.PosW, In.NormV, In.ViewDirV, LightDirV, lPos[i], lAtt0[i],lAtt1[i],lAtt2[i], lAmb[i], lDiff[i], lSpec[i],specIntensity).rgb;
					
				}
			
				break;
		}
		
	}


		newCol += (fresRim * RimColor);


	col *= float4((newCol * Color.rgb), Alpha);
    return col;
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

