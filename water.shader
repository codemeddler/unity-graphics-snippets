Shader "Custom/water"
{
    Properties
    {
        _Color ("Tint Color", Color) = (0.5, 0.5, 0.5, 0.5)
        _MainTex ("Texture", 2D) = "white" {}
        _NormalMap ("Normals", 2D) = "bump" {}
        _NoiseTex ("Noise", 2D) = "white" {}
        _ScrollSpeed ("Scroll Speed", Float) = 2.0
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
        }
        Pass
        {
            Tags
            {
                "LightMode" = "ForwardBase"
            }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"

            uniform half4 _LightColor0;
            half4 _Color;
            sampler2D _MainTex;
            sampler2D _NoiseTex;
            sampler2D _NormalMap;
            half _ScrollSpeed;

            struct vertex_input
            {
                half4 vertex : POSITION;
                half2 uv : TEXCOORD0;
                half3 normal : NORMAL;
                half4 tangent : TANGENT;
            };
            
            struct vertex_output
            {
                half4 pos : SV_POSITION;
                half2 uv : TEXCOORD0;
                half3 pos_ws : TEXCOORD1;
                half3 tangent_space_x : TEXCOORD2;
                half3 tangent_space_y : TEXCOORD3;
                half3 tangent_space_z : TEXCOORD4;
            };

            vertex_output vert(vertex_input v)
            {
                vertex_output o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.pos_ws = mul(unity_ObjectToWorld, v.vertex);
                half3 normal_ws = UnityObjectToWorldNormal(v.normal);
                half3 tangent_ws = UnityObjectToWorldDir(v.tangent.xyz);
                half tangent_sign = v.tangent.w * unity_WorldTransformParams.w;
                half3 bi_tangent_ws = cross(normal_ws, tangent_ws) * tangent_sign;
                o.tangent_space_x = half3(tangent_ws.x, bi_tangent_ws.x, normal_ws.x);
                o.tangent_space_y = half3(tangent_ws.y, bi_tangent_ws.y, normal_ws.y);
                o.tangent_space_z = half3(tangent_ws.z, bi_tangent_ws.z, normal_ws.z);
                return o;
            }

            half4 frag(vertex_output i) : SV_Target
            {
                half noise_sample = tex2D(_NoiseTex, i.uv);
                half time = _Time.y * _ScrollSpeed;
                half2 normal_uv = i.uv + time;
                half3 tangent_normal = UnpackNormal(tex2D(_NormalMap, normal_uv));
                half3 world_normal;
                world_normal.x = dot(i.tangent_space_x, tangent_normal);
                world_normal.y = dot(i.tangent_space_y, tangent_normal);
                world_normal.z = dot(i.tangent_space_z, tangent_normal);
                half3 world_view_dir = normalize(UnityWorldSpaceViewDir(i.pos_ws));
                half3 world_reflection = reflect(-world_view_dir, world_normal);
                half4 sky_data = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, world_reflection);
                half time_color = _Time.y * _ScrollSpeed * noise_sample;
                half2 color_uv = i.uv - sin(time_color);
                half3 surface_color = tex2D(_MainTex, color_uv) * _Color;
                half3 ambient_lighting = ShadeSH9(half4(world_normal, 1.0h));
                half3 sky_color = DecodeHDR(sky_data, unity_SpecCube0_HDR);
                half3 color = ambient_lighting * surface_color + surface_color * _LightColor0 * sky_color;
                return half4(color, 1.0h);
            }
            ENDCG
        }
    }
}