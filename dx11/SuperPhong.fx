//@author: mburk
//@help: 
//@tags: shading, blinn
//@credits: Vux, Dottore, Catweasel

// -----------------------------------------------------------------------------
// PARAMETERS:
// -----------------------------------------------------------------------------


cbuffer cbPerRender : register( b0 )
{
	float4x4 tP: PROJECTION;   //projection matrix as set via Renderer
	float4x4 tV: VIEW;         //view matrix as set via Renderer
	float2 KrMin <String uiname="Fresnel Rim/Refl Min ";float uimin=0.0; float uimax=1;> = 0.002 ;
	float2 Kr <String uiname="Fresnel Rim/Refl Max ";float uimin=0.0; float uimax=6.0;> = 0.5 ;
	float2 FresExp <String uiname="Fresnel Rim/Refl Exp ";float uimin=0.0; float uimax=30;> = 5 ;
	float3 camPos;
	float4 RimColor <bool color = true; string uiname="Rim Color";>  = { 0.0f,0.0f,0.0f,0.0f };
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
	float reflective <String uiname="Reflective";float uimin=0.0; float uimax=30;> = 1 ;
	bool BPCM;
	bool refraction = false;
	float refractionIndex = 1.2;
	int cubeMapMode <String uiname="CubeMap Mode Reflective/Normal"; int uimin=0.0; int uimax=1.0;> = 0;
	float3 cubeMapPos  <string uiname="CubeMapPos"; > = float3(0,0,0);
	int reflectMode <string uiname="ReflectionMode: Mul/Add"; int uimin=0.0; int uimax=1.0;> = 1;
	int diffuseMode <string uiname="DiffuseAffect: Reflection/Specular/Both"; int uimin=0.0; int uimax=2.0;> = 0;
};
	
	float4x4 NormalTransform <string uiname="NormalRotation";>;

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

	StructuredBuffer <float3> cubeMapBoxBounds <string uiname="CubeMapBounds";>;

#include "PhongPoint.fxh"
#include "PhongPointSpot.fxh"
#include "PhongDirectional.fxh"

SamplerState g_samLinear
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp;
    AddressV = Clamp;
};

SamplerState g_samLinearRefl
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = BORDER;
    AddressV = BORDER;
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

	
//  BumpMap
///////////////////////////////////////
	float3 tangent : TEXCOORD6;
	float3 binormal : TEXCOORD7;
///////////////////////////////////////	

	float4 reflectionPosition : TEXCOORD8;

};

// -----------------------------------------------------------------------------
// VERTEXSHADERS
// -----------------------------------------------------------------------------

vs2ps VS_Bump(
    float4 PosO: POSITION,
    float3 NormO: NORMAL,
    float4 TexCd : TEXCOORD0,
//  BumpMap (Remove last Comma if commented)
///////////////////////////////////////
	float3 tangent : TANGENT,
    float3 binormal : BINORMAL
///////////////////////////////////////
)
{
    //inititalize all fields of output struct with 0
    vs2ps Out = (vs2ps)0;

    Out.PosW = mul(PosO, tW).xyz;
	Out.PosO = PosO;
	
   // Out.NormW = mul(NormO, tW);
	
	Out.NormW = mul(NormO, NormalTransform);
	
    //normal in view space
    Out.NormV = normalize(mul(mul(NormO, (float3x3)tWIT),(float3x3)tV).xyz);

//  BumpMap
///////////////////////////////////////
	// Calculate the tangent vector against the world matrix only and then normalize the final value.
    Out.tangent = mul(tangent, tW);
    Out.tangent = normalize(Out.tangent);

    // Calculate the binormal vector against the world matrix only and then normalize the final value.
    Out.binormal = mul(binormal, tW);
    Out.binormal = normalize(Out.binormal);
///////////////////////////////////////

//	position (projected)
    Out.PosWVP  = mul(PosO, tWVP);

	Out.TexCd = TexCd;
    Out.ViewDirV = -normalize(mul(PosO, tWV).xyz);
	
	
    return Out;
}




vs2ps VS(
    float4 PosO: POSITION,
    float3 NormO: NORMAL,
    float4 TexCd : TEXCOORD0

)
{
    //inititalize all fields of output struct with 0
    vs2ps Out = (vs2ps)0;
	
	Out.PosO = PosO;
    Out.PosW = mul(PosO, tW).xyz;
    Out.NormW = mul(NormO, NormalTransform);
	
	
    //normal in view space
    Out.NormV = normalize(mul(mul(NormO, (float3x3)tWIT),(float3x3)tV).xyz);


//	position (projected)
    Out.PosWVP  = mul(PosO, tWVP);

	Out.TexCd = TexCd;
    Out.ViewDirV = -normalize(mul(PosO, tWV).xyz);
	

	
    return Out;
}

// -----------------------------------------------------------------------------
// PIXELSHADERS:
// -----------------------------------------------------------------------------
float Alpha <float uimin=0.0; float uimax=1.0;> = 1;

float4 PS_SuperphongBump(vs2ps In): SV_Target
{	
	
	float3 LightDirW;
	float3 LightDirV;
	float4 viewPosition;
	float2 projectTexCoord;
	float4 projectionColor;
	float2 reflectTexCoord;
	float4 reflectionColor;
	
	uint numTexTrans, dummy;
    texTransforms.GetDimensions(numTexTrans, dummy);
	
	float4 col = texture2d.Sample(g_samLinear, mul(In.TexCd.xy,texTransforms[0%numTexTrans]));
	float4 specIntensity = specTex.Sample(g_samLinear, mul(In.TexCd.xy,texTransforms[1%numTexTrans]));
	float4 diffuse = diffuseTex.Sample(g_samLinear, mul(In.TexCd.xy,texTransforms[2%numTexTrans]));
	
	if(diffuseMode == 1 || diffuseMode ==2){
		specIntensity *= length(diffuse.rgb);
	}
	
	float3 newCol;
	float3 Nn = normalize(In.NormW);
	
//  BumpMap
///////////////////////////////////////
	float4 bumpMap = normalTex.Sample(g_samLinear, mul(In.TexCd.xy,texTransforms[3%numTexTrans]));
	
	bumpMap = (bumpMap * 2.0f) - 1.0f;
	
    float3 bumpNormal = (bumpMap.x * In.tangent) + (bumpMap.y * In.binormal) + (bumpMap.z * In.NormW);

    bumpNormal = normalize(bumpNormal);
	
	In.NormV += bumpNormal*bumpy;
	
    float3 Tn = normalize(In.tangent);
    float3 Bn = normalize(In.binormal);
	float3 Nb = Nn + (bumpMap.x * Tn + bumpMap.y * Bn)*bumpy;
///////////////////////////////////////
	
// Reflection and RimLight
	float3 Vn = normalize(camPos - In.PosW);
	
//BumpMap
///////////////////////////////////////
	float3 reflVect = -reflect(Vn,Nb);
	float3 reflVecNorm = Nn-reflect(Nn,Nb);
	float3 refrVect = refract(-Vn, Nb , refractionIndex);
///////////////////////////////////////

	
	
	// Box Projected CubeMap
	////////////////////////////////////////////////////
	
	if(BPCM){
		
		
		float3 rbmax = (cubeMapBoxBounds[0] - (In.PosW))/reflVect;
		float3 rbmin = (cubeMapBoxBounds[1] - (In.PosW))/reflVect;
		
		float3 rbminmax = (reflVect>0.0f)?rbmax:rbmin;
		
		float fa = min(min(rbminmax.x, rbminmax.y), rbminmax.z);
		
		float3 posonbox = In.PosW + reflVect*fa;
		reflVect = posonbox - cubeMapPos;
		
		if(cubeMapMode == 1){
				
		
			rbmax = (cubeMapBoxBounds[0] - (In.PosW))/reflVecNorm;
			rbmin = (cubeMapBoxBounds[1] - (In.PosW))/reflVecNorm;
			
			rbminmax = (reflVecNorm>0.0f)?rbmax:rbmin;
			
			fa = min(min(rbminmax.x, rbminmax.y), rbminmax.z);
			
			posonbox = In.PosW + reflVecNorm*fa;
			reflVecNorm = posonbox - cubeMapPos;
			
		}
		
		if(refraction){
			rbmax = (cubeMapBoxBounds[0] - (In.PosW))/refrVect;
			rbmin = (cubeMapBoxBounds[1] - (In.PosW))/refrVect;
			
			rbminmax = (refrVect>0.0f)?rbmax:rbmin;
			
			fa = min(min(rbminmax.x, rbminmax.y), rbminmax.z);
			
			posonbox = In.PosW + refrVect*fa;
			refrVect = posonbox - cubeMapPos;
		}
		
	}
	
	////////////////////////////////////////////////////
	
	
	float vdn = -saturate(dot(Vn,In.NormW));
   	float fresRim = KrMin.x + (Kr.x-KrMin.x) * pow(1-abs(vdn),FresExp.x);
	float fresRefl = KrMin.y + (Kr.y-KrMin.y) * pow(1-abs(vdn),FresExp.y);
	float4 reflColor = float4(0,0,0,0);
	float4 refrColor = float4(0,0,0,0);
	
	if(cubeMapMode == 0){
		reflColor += cubeTex.Sample(g_samLinear,float3(reflVect.x, reflVect.y, reflVect.z));
		if(refraction) refrColor = cubeTex.Sample(g_samLinear,float3(refrVect.x, refrVect.y, refrVect.z));
		reflColor = lerp(refrColor,reflColor,fresRefl);
	}
	
	if(cubeMapMode == 1){
		reflColor =  cubeTex.Sample(g_samLinear,reflVecNorm);		
	}
	
	if(diffuseMode == 0 || diffuseMode ==2){
			reflColor *= length(diffuse.rgb);
			
	} 
	
	uint d,textureCount;
	lightMap.GetDimensions(d,d,textureCount);
	
	uint numSpotRange, dummySpot;
    texTransforms.GetDimensions(numSpotRange, dummySpot);
	
	uint numlAmb, dummyAmb;
    lAmb.GetDimensions(numlAmb, dummyAmb);
	
	uint numlDiff, dummyDiff;
    lDiff.GetDimensions(numlDiff, dummyDiff);
	
	uint numlSpec, dummySpec;
    lSpec.GetDimensions(numlSpec, dummySpec);
	
	uint numlAtt0, dummylAtt0;
    lAmb.GetDimensions(numlAtt0, dummylAtt0);
	
	uint numlAtt1, dummylAtt1;
    lAmb.GetDimensions(numlAtt1, dummylAtt1);
	
	uint numlAtt2, dummylAtt2;
    lAmb.GetDimensions(numlAtt2, dummylAtt2);
	
	uint numLVP, dummyLVP;
    lAmb.GetDimensions(numLVP, dummyLVP);
	
	
	for(int i = 0; i< lightCount; i++){
		float3 lightToObject = lPos[i] - In.PosW;
		switch (lightType[i]){
			case 0:
				LightDirV = normalize(-mul(lPos[i], tV));
				newCol += PhongDirectional(In.NormV, In.ViewDirV, LightDirV, lAmb[i%numlAmb], lDiff[i%numlDiff], lSpec[i%numlSpec],specIntensity).rgb;
				break;

			
			case 1:
				
				if(length(lightToObject) < spotRange[i%numSpotRange]){	
					
					LightDirW = normalize(lightToObject);
					LightDirV = mul(float4(LightDirW,0.0f), tV).xyz;
			  		newCol += PhongPoint(In.PosW, In.NormV, In.ViewDirV, LightDirV, lPos[i], lAtt0[i%numlAtt0],lAtt1[i%numlAtt1],lAtt2[i%numlAtt2], lAmb[i%numlAmb], lDiff[i%numlDiff], lSpec[i%numlSpec],specIntensity).rgb;
					
				}
			
				break;
			
			case 2:

				if(length(lightToObject) < spotRange[i%numSpotRange]){
					viewPosition = mul(In.PosO, tW);
					viewPosition = mul(viewPosition, LightVP[i%numLVP]);
					
					projectTexCoord.x =  viewPosition.x / viewPosition.w / 2.0f + 0.5f;
		   			projectTexCoord.y = -viewPosition.y / viewPosition.w / 2.0f + 0.5f;
					
					float3 coords = float3(projectTexCoord, i % textureCount);	//make sure Instance ID buffer is in floats
					projectionColor = lightMap.Sample(g_samLinear, coords, 0 );
					projectionColor *= saturate(1/(viewPosition.z*lightMapFade));					
					LightDirW = normalize(lightToObject);
					LightDirV = mul(float4(LightDirW,0.0f), tV).xyz;
			  		newCol += PhongPointSpot(In.PosW, In.NormV, In.ViewDirV, LightDirV, lPos[i], lAtt0[i%numlAtt0],lAtt1[i%numlAtt1],lAtt2[i%numlAtt2], lAmb[i%numlAmb], lDiff[i%numlDiff], lSpec[i%numlSpec],specIntensity, projectTexCoord,projectionColor).rgb;
					
				}
			
				break;
		}
		
		newCol += lAmb[0];
	}

	if(reflectMode == 0){
		newCol *= (reflColor*reflective.x);
		newCol += (fresRim * RimColor);
		
	} else{
		newCol += (reflColor*reflective.x);
		newCol += (fresRim * RimColor);
	}	

	col *= float4((newCol * Color.rgb), Alpha);
    return col;
}


float4 PS_Superphong(vs2ps In): SV_Target
{	
	
	float3 LightDirW;
	float3 LightDirV;
	float4 viewPosition;
	float2 projectTexCoord;
	float4 projectionColor;
	float2 reflectTexCoord;
    float4 reflectionColor;
	
	uint numTexTrans, dummy;
    texTransforms.GetDimensions(numTexTrans, dummy);
	
	float4 col = texture2d.Sample(g_samLinear, mul(In.TexCd.xy,texTransforms[0%numTexTrans]));
	float4 specIntensity = specTex.Sample(g_samLinear, mul(In.TexCd.xy,texTransforms[1%numTexTrans]));
	float4 diffuse = diffuseTex.Sample(g_samLinear, mul(In.TexCd.xy,texTransforms[2%numTexTrans]));
	
	if(diffuseMode == 1 || diffuseMode ==2){
		specIntensity *= length(diffuse.rgb);
	}
	
	
	float3 newCol;

	float3 Nn = normalize(In.NormW);
	
	
// Reflection and RimLight

	float3 Vn = normalize(camPos - In.PosW);

	float vdn = -saturate(dot(Vn,In.NormW));

   	float4 fresRim = KrMin.x + (Kr.x-KrMin.x) * (pow(1-abs(vdn),FresExp.x));
	float4 fresRefl = KrMin.y + (Kr.y-KrMin.y) * (pow(1-abs(vdn),FresExp.y));
	
	float3 reflVect = -reflect(Vn,Nn);
	float3 reflVecNorm = Nn;
	float3 refrVect = refract(-Vn, Nn , refractionIndex);
	
	
// Box Projected CubeMap
	////////////////////////////////////////////////////
	
	if(BPCM){
		
		
		float3 rbmax = (cubeMapBoxBounds[0] - (In.PosW))/reflVect;
		float3 rbmin = (cubeMapBoxBounds[1] - (In.PosW))/reflVect;
		
		float3 rbminmax = (reflVect>0.0f)?rbmax:rbmin;
		
		float fa = min(min(rbminmax.x, rbminmax.y), rbminmax.z);
		
		float3 posonbox = In.PosW + reflVect*fa;
		reflVect = posonbox - cubeMapPos;
		
		if(cubeMapMode == 1){
				
		
			rbmax = (cubeMapBoxBounds[0] - (In.PosW))/reflVecNorm;
			rbmin = (cubeMapBoxBounds[1] - (In.PosW))/reflVecNorm;
			
			rbminmax = (reflVecNorm>0.0f)?rbmax:rbmin;
			
			fa = min(min(rbminmax.x, rbminmax.y), rbminmax.z);
			
			posonbox = In.PosW + reflVecNorm*fa;
			reflVecNorm = posonbox - cubeMapPos;
			
		}
		
		if(refraction){
			rbmax = (cubeMapBoxBounds[0] - (In.PosW))/refrVect;
			rbmin = (cubeMapBoxBounds[1] - (In.PosW))/refrVect;
			
			rbminmax = (refrVect>0.0f)?rbmax:rbmin;
			
			fa = min(min(rbminmax.x, rbminmax.y), rbminmax.z);
			
			posonbox = In.PosW + refrVect*fa;
			refrVect = posonbox - cubeMapPos;
		}
		
	}
	
////////////////////////////////////////////////////
	
	float4 reflColor = float4(0,0,0,0);
	float4 refrColor = float4(0,0,0,0);

	
	if(cubeMapMode == 0){
		
		//reflColor = fresRefl * cubeTex.Sample(g_samLinear,float3(reflVect.x, reflVect.y, reflVect.z));
		reflColor = cubeTex.Sample(g_samLinear,float3(reflVect.x, reflVect.y, reflVect.z));	
		if(refraction) refrColor = cubeTex.Sample(g_samLinear,float3(refrVect.x, refrVect.y, refrVect.z));
		reflColor = lerp(refrColor,reflColor,fresRefl);
	}
	
	if(cubeMapMode == 1){
		
		reflColor =  cubeTex.Sample(g_samLinear,reflVecNorm);	
		 	
	}
	
	if(diffuseMode == 0 || diffuseMode ==2){
			reflColor *= length(diffuse.rgb);			
	} 
	
	


	uint d,textureCount;
	lightMap.GetDimensions(d,d,textureCount);
	
	uint numSpotRange, dummySpot;
    texTransforms.GetDimensions(numSpotRange, dummySpot);
	
	uint numlAmb, dummyAmb;
    lAmb.GetDimensions(numlAmb, dummyAmb);
	
	uint numlDiff, dummyDiff;
    lDiff.GetDimensions(numlDiff, dummyDiff);
	
	uint numlSpec, dummySpec;
    lSpec.GetDimensions(numlSpec, dummySpec);
	
	uint numlAtt0, dummylAtt0;
    lAmb.GetDimensions(numlAtt0, dummylAtt0);
	
	uint numlAtt1, dummylAtt1;
    lAmb.GetDimensions(numlAtt1, dummylAtt1);
	
	uint numlAtt2, dummylAtt2;
    lAmb.GetDimensions(numlAtt2, dummylAtt2);
	
	uint numLVP, dummyLVP;
    lAmb.GetDimensions(numLVP, dummyLVP);
	
	for(int i = 0; i< lightCount; i++){
		float3 lightToObject = lPos[i] - In.PosW;
		switch (lightType[i]){
			case 0:
				LightDirV = normalize(-mul(lPos[i], tV));
				newCol += PhongDirectional(In.NormV, In.ViewDirV, LightDirV, lAmb[i%numlAmb], lDiff[i%numlDiff], lSpec[i%numlSpec],specIntensity).rgb;
				break;

			
			case 1:
				
				if(length(lightToObject) < spotRange[i%numSpotRange]){	
					
					LightDirW = normalize(lightToObject);
					LightDirV = mul(float4(LightDirW,0.0f), tV).xyz;
			  		newCol += PhongPoint(In.PosW, In.NormV, In.ViewDirV, LightDirV, lPos[i], lAtt0[i%numlAtt0],lAtt1[i%numlAtt1],lAtt2[i%numlAtt2], lAmb[i%numlAmb], lDiff[i%numlDiff], lSpec[i%numlSpec],specIntensity).rgb;
					
				}
			
				break;
			
			case 2:

				if(length(lightToObject) < spotRange[i%numSpotRange]){
					viewPosition = mul(In.PosO, tW);
					viewPosition = mul(viewPosition, LightVP[i%numLVP]);
					
					projectTexCoord.x =  viewPosition.x / viewPosition.w / 2.0f + 0.5f;
		   			projectTexCoord.y = -viewPosition.y / viewPosition.w / 2.0f + 0.5f;
					
					
					float3 coords = float3(projectTexCoord, i % textureCount);	//make sure Instance ID buffer is in floats
					projectionColor = lightMap.Sample(g_samLinear, coords, 0 );
					projectionColor *= saturate(1/(viewPosition.z*lightMapFade));					
					LightDirW = normalize(lightToObject);
					LightDirV = mul(float4(LightDirW,0.0f), tV).xyz;
			  		newCol += PhongPointSpot(In.PosW, In.NormV, In.ViewDirV, LightDirV, lPos[i], lAtt0[i%numlAtt0],lAtt1[i%numlAtt1],lAtt2[i%numlAtt2], lAmb[i%numlAmb], lDiff[i%numlDiff], lSpec[i%numlSpec],specIntensity, projectTexCoord,projectionColor).rgb;
					
				}
			
				break;
		}
		
		newCol += lAmb[0];
		
	}

	
	if(reflectMode == 0){
		newCol *= (reflColor*reflective.x);
		newCol += (fresRim * RimColor);
		
	} else{
		newCol += (reflColor*reflective.x);
		newCol += (fresRim * RimColor);
	}	
	
	
	col *= float4((newCol * Color.rgb), Alpha);
    return col;
}

// -----------------------------------------------------------------------------
// TECHNIQUES:
// -----------------------------------------------------------------------------


technique10 Superphong
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS() ) );
		SetPixelShader( CompileShader( ps_5_0, PS_Superphong() ) );
	}
}

technique10 Superphong_Bump
{
	pass P0
	{
		SetVertexShader( CompileShader( vs_4_0, VS_Bump() ) );
		SetPixelShader( CompileShader( ps_5_0, PS_SuperphongBump() ) );
	}
}