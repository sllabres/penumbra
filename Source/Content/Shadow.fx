﻿cbuffer cbConstant
{
	float4 Color; // Used in debugging.
};

cbuffer cbPerObject
{
	float2 LightPosition;
	float4x4 WorldViewProjection;
};

struct VertexIn
{	
	float2 SegmentA : TEXCOORD0;
	float2 SegmentB : TEXCOORD1;
	float2 OccluderCoord : SV_POSITION0;
	float Radius : NORMAL0;
};

struct VertexOut
{
	float4 Position : SV_POSITION;
	float4 Penumbra : TEXCOORD1;
	float ClipValue : TEXCOORD2;
};

float2x2 penumbraMatrix(float2 basisX, float2 basisY) 
{
	float2x2 m = float2x2(basisX, basisY);
	// Find inverse of m.
	return float2x2(m._m11, -m._m01, -m._m10, m._m00) / determinant(m);
}

VertexOut VS(VertexIn vin)
{
	float2 occluderCoord = vin.OccluderCoord;	
	// Ensure radius never reaches 0.
	float radius = max(1e-5, vin.Radius);	

	float2 segmentA = vin.SegmentA;
	float2 segmentB = vin.SegmentB;
	float2 toSegmentA = vin.SegmentA - LightPosition;
	float2 toSegmentB = vin.SegmentB - LightPosition;

	// Find radius offsets 90deg left and right from light source relative to vertex.
	float2 lightOffsetA = float2(-radius, radius)*normalize(toSegmentA).yx; // 90 CCW.
	float2 lightOffsetB = float2(radius, -radius)*normalize(toSegmentB).yx; // 90 CW.

	// From each edge, project a quad. 4 vertices per edge.	
	float2 position = lerp(segmentA, segmentB, occluderCoord.x);	
	float2 projectionOffset = lerp(lightOffsetA, lightOffsetB, occluderCoord.x);	
	float4 projected = float4((position - projectionOffset*occluderCoord.y)*9000*occluderCoord.y, 0.0, 1.0 - occluderCoord.y);	

	// Transform to ndc.
	float4 clipPosition = mul(projected, WorldViewProjection);
	
	float2 penumbraA = mul(projected.xy - segmentA*projected.w, penumbraMatrix(lightOffsetA, segmentA));
	float2 penumbraB = mul(projected.xy - segmentB*projected.w, penumbraMatrix(lightOffsetB, segmentB));

	float2 clipNormal = normalize(toSegmentB - toSegmentA).yx*float2(-1.0, 1.0);
	// 90 CCW. ClipValue > 0 means the projection is pointing towards us => no shadow should be generated.
	float clipValue = dot(clipNormal, projected.xy - projected.w*position);
	
	VertexOut vout;
	vout.Position = clipPosition;
	vout.Penumbra = float4(penumbraA, penumbraB);
	vout.ClipValue = clipValue;

	/*if (penumbraA.x == 0 && penumbraA.y == 0)
	{
		vout.position = float4(-1, -1, 0, 1);
	}*/

	return vout;
}

float4 PS(VertexOut pin) : SV_TARGET
{
	// If clipvalue > 0, dont shadow.
	clip(-pin.ClipValue);

	float2 p = clamp(pin.Penumbra.xz / pin.Penumbra.yw, -1.0, 1.0);
	float2 value = lerp(p*(3.0 - p*p)*0.25 + 0.5, 1.0, step(pin.Penumbra.yw, 0.0));	
	float occlusion = (value[0] + value[1] - 1.0);
	return float4(0.0, 0.0, 0.0, occlusion);
}

float4 PSDebug(VertexOut pin) : SV_TARGET
{
	clip(-pin.ClipValue);
	return Color;
}

technique Main
{
	pass P0
	{
		VertexShader = compile vs_4_0_level_9_1 VS();
		PixelShader = compile ps_4_0_level_9_1 PS();
	}
}

technique Debug
{
	pass P0
	{
		VertexShader = compile vs_4_0_level_9_1 VS();
		PixelShader = compile ps_4_0_level_9_1 PSDebug();
	}
}
