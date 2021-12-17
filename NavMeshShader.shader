Shader "Custom/NavMeshShader" {
	SubShader {
		Tags { "RenderType"="Transparent" }
		LOD 200
		
		CGPROGRAM
		#pragma surface surf Lambert alpha

		struct Input {
			float4 color : COLOR;
		};
		
		void surf (Input IN, inout SurfaceOutput o) {
			
			o.Albedo.g = 1;
			o.Alpha = 0.25;
		}
		ENDCG
	} 
	FallBack "Diffuse"
}
