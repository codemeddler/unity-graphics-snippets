Shader "Custom/flat"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _NormalMap("Normal Map", 2D) = "bump" {}
        _Color ("Solid Color", Color) = (0.0, 0.0, 0.0, 1.0)
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
            #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap
            #pragma multi_compile_instancing
            #pragma multi_compile_fog
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"

            uniform half4 _LightColor0;
            sampler2D _MainTex;
            sampler2D _NormalMap;
            half4 _MainTex_ST;
            half4 _NormalMap_ST;

            struct vertex_input
            {
                UNITY_VERTEX_INPUT_INSTANCE_ID
                half4 vertex : POSITION;
                half3 normal : NORMAL;
                half4 tangent : TANGENT;
                half4 uv : TEXCOORD0;
            };

            struct vertex_output
            {
                UNITY_VERTEX_INPUT_INSTANCE_ID
                half4 pos : SV_POSITION;
                half3 normal : NORMAL;
                half2 uv : TEXCOORD0;
                half4 pos_ws : TEXCOORD1;
                half3 tangent : TEXCOORD2;
                half3 vertex_light : TEXCOORD3;
                SHADOW_COORDS(4)
                UNITY_FOG_COORDS(5)
            };

            vertex_output vert(vertex_input v)
            {
                vertex_output o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.normal = normalize(mul(half4(v.normal, 0.0h), unity_WorldToObject).xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.pos_ws = mul(unity_ObjectToWorld, v.vertex);
                o.tangent = normalize(mul(unity_ObjectToWorld, half4(v.tangent.xyz, 0.0h)).xyz);
                o.vertex_light = Shade4PointLights(
                    unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
                    unity_LightColor[0].rgb, unity_LightColor[1].rgb,
                    unity_LightColor[2].rgb, unity_LightColor[3].rgb,
                    unity_4LightAtten0, o.pos_ws, o.normal
                );
                TRANSFER_SHADOW(o);
                UNITY_TRANSFER_FOG(o, o.pos);
                return o;
            }

            UNITY_INSTANCING_BUFFER_START(InstanceProperties)
            UNITY_DEFINE_INSTANCED_PROP(half4, _Color)
            UNITY_INSTANCING_BUFFER_END(InstanceProperties)

            half4 frag(vertex_output i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                half3 bi_normal_direction = cross(i.tangent, i.normal);
                half3x3 tangent_transform = float3x3( i.tangent, bi_normal_direction, i.normal);
                half3 encoded_normal = UnpackNormal(tex2D(_NormalMap, _NormalMap_ST.xy * i.uv.xy + _NormalMap_ST.zw));
                float3 normal_direction = normalize(mul(encoded_normal, tangent_transform));

                half3 light_direction = _WorldSpaceLightPos0.xyz - i.pos_ws.xyz * _WorldSpaceLightPos0.w;
                half n_dot_l = saturate(dot(normal_direction, light_direction));

                half3 surface_color = tex2D(_MainTex, i.uv * _MainTex_ST.xy + _MainTex_ST.zw);
                surface_color *= UNITY_ACCESS_INSTANCED_PROP(InstanceProperties, _Color);

                half one_over_distance = 1.0h / length(light_direction);
                half attenuation = lerp(1.0h, one_over_distance, _WorldSpaceLightPos0.w);

                half half_lambert_diffuse = pow(n_dot_l * 0.5h + 0.5h, 2.0h) * surface_color;
                half shadow = SHADOW_ATTENUATION(i);

                half3 final_color = ShadeSH9(half4(i.normal, 1.0h)) * surface_color + half_lambert_diffuse * attenuation
                    * _LightColor0.rgb * surface_color * shadow + i.vertex_light;
                UNITY_APPLY_FOG(i.fogCoord, final_color);
                return half4(final_color, 1.0h);
            }
            ENDCG
        }
        Pass
        {
            Tags
            {
                "LightMode" = "ForwardAdd"
            }
            Blend One One
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdadd_fullshadows nolightmap nodirlightmap nodynlightmap
            #pragma multi_compile_instancing
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"

            uniform half4 _LightColor0;
            sampler2D _MainTex;
            sampler2D _NormalMap;
            half4 _MainTex_ST;
            half4 _NormalMap_ST;

            struct vertex_input
            {
                UNITY_VERTEX_INPUT_INSTANCE_ID
                half4 vertex : POSITION;
                half3 normal : NORMAL;
                half4 tangent : TANGENT;
                half4 uv : TEXCOORD0;
            };

            struct vertex_output
            {
                UNITY_VERTEX_INPUT_INSTANCE_ID
                half4 pos : SV_POSITION;
                half3 normal : NORMAL;
                half2 uv : TEXCOORD0;
                half4 pos_ws : TEXCOORD1;
                half3 tangent : TEXCOORD2;
                SHADOW_COORDS(3)
            };

            vertex_output vert(vertex_input v)
            {
                vertex_output o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.normal = normalize(mul(half4(v.normal, 0.0h), unity_WorldToObject).xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.pos_ws = mul(unity_ObjectToWorld, v.vertex);
                o.tangent = normalize(mul(unity_ObjectToWorld, half4(v.tangent.xyz, 0.0h)).xyz);
                TRANSFER_SHADOW(o);
                return o;
            }

            UNITY_INSTANCING_BUFFER_START(InstanceProperties)
            UNITY_DEFINE_INSTANCED_PROP(half4, _Color)
            UNITY_INSTANCING_BUFFER_END(InstanceProperties)

            half4 frag(vertex_output i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                half3 bi_normal_direction = cross(i.tangent, i.normal);
                half3x3 tangent_transform = float3x3( i.tangent, bi_normal_direction, i.normal);
                half3 encoded_normal = UnpackNormal(tex2D(_NormalMap, _NormalMap_ST.xy * i.uv.xy + _NormalMap_ST.zw));
                float3 normal_direction = normalize(mul(encoded_normal, tangent_transform));

                half3 light_direction = _WorldSpaceLightPos0.xyz - i.pos_ws.xyz * _WorldSpaceLightPos0.w;
                half n_dot_l = saturate(dot(normal_direction, light_direction));

                half3 surface_color = tex2D(_MainTex, i.uv * _MainTex_ST.xy + _MainTex_ST.zw);
                surface_color *= UNITY_ACCESS_INSTANCED_PROP(InstanceProperties, _Color);

                half one_over_distance = 1.0h / length(light_direction);
                half attenuation = lerp(1.0h, one_over_distance, _WorldSpaceLightPos0.w);

                half half_lambert_diffuse = pow(n_dot_l * 0.5h + 0.5h, 2.0h) * surface_color;
                half shadow = SHADOW_ATTENUATION(i);

                half3 final_color = half_lambert_diffuse * attenuation * _LightColor0.rgb * surface_color * shadow;
                return half4(final_color, 1.0h);
            }
            ENDCG
        }
        Pass
        {
            Tags
            {
                "LightMode"="ShadowCaster"
            }

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            #pragma multi_compile_instancing
            #include "UnityCG.cginc"

            struct v2f
            {
                UNITY_VERTEX_INPUT_INSTANCE_ID
                V2F_SHADOW_CASTER;
            };

            UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
            UNITY_INSTANCING_BUFFER_END(Props)

            v2f vert(appdata_base v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }
    }
}