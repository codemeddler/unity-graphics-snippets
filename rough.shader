Shader "Custom/rough"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Solid Color", Color) = (0.0, 0.0, 0.0, 1.0)
        _Roughness ("Roughness", Float) = 0.2
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
            half4 _MainTex_ST;

            struct vertex_input
            {
                UNITY_VERTEX_INPUT_INSTANCE_ID
                half4 vertex : POSITION;
                half3 normal : NORMAL;
                half4 uv : TEXCOORD0;
            };

            struct vertex_output
            {
                UNITY_VERTEX_INPUT_INSTANCE_ID
                half4 pos : SV_POSITION;
                half3 normal : NORMAL;
                half2 uv : TEXCOORD0;
                half4 pos_ws : TEXCOORD2;
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
                o.normal = normalize(mul(half4(v.normal, 0.0h), unity_WorldToObject).xyz);;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.pos_ws = mul(unity_ObjectToWorld, v.vertex);
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
            UNITY_DEFINE_INSTANCED_PROP(half, _Roughness)
            UNITY_INSTANCING_BUFFER_END(InstanceProperties)

            half4 frag(vertex_output i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                half3 light_direction_ws = _WorldSpaceLightPos0.xyz - i.pos_ws.xyz;
                half one_over_distance = 1.0h / length(light_direction_ws);
                half attenuation = lerp(1.0h, one_over_distance, _WorldSpaceLightPos0.w);

                half3 light_direction = _WorldSpaceLightPos0.xyz - i.pos_ws.xyz * _WorldSpaceLightPos0.w;
                half3 normal_direction = normalize(i.normal);
                half3 view_direction = normalize(_WorldSpaceCameraPos - i.pos_ws.xyz);

                half roughness = UNITY_ACCESS_INSTANCED_PROP(InstanceProperties, _Roughness);
                half roughness_squared = roughness * roughness;
                half3 o_n_fraction = roughness_squared / (roughness_squared + half3(0.33h, 0.13h, 0.09h));
                half3 oren_nayar = half3(1.0h, 0.0h, 0.0h) + half3(-0.5h, 0.17h, 0.45h) * o_n_fraction;
                half cos_ndotl = saturate(dot(normal_direction, light_direction));
                half cos_ndotv = saturate(dot(normal_direction, view_direction));
                half oren_nayar_s = saturate(dot(light_direction, view_direction)) - cos_ndotl * cos_ndotv;
                oren_nayar_s /= lerp(max(cos_ndotl, cos_ndotv), 1.0h, step(oren_nayar_s, 0.0h));

                half3 surface_color = tex2D(_MainTex, i.uv * _MainTex_ST.xy + _MainTex_ST.zw);
                surface_color *= UNITY_ACCESS_INSTANCED_PROP(InstanceProperties, _Color).rgb;

                half3 lighting_model = _LightColor0.rgb * cos_ndotl * (oren_nayar.x + _LightColor0.rgb * oren_nayar.y +
                    oren_nayar.z * oren_nayar_s);
                half3 attenuation_color = attenuation * _LightColor0.rgb;
                half3 final_diffuse = lighting_model * attenuation_color;
                half shadow = SHADOW_ATTENUATION(i);
                half3 final_color = ShadeSH9(half4(normal_direction, 1.0h)) * surface_color + final_diffuse *
                    surface_color * shadow + i.vertex_light;

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
            half4 _MainTex_ST;

            struct vertex_input
            {
                UNITY_VERTEX_INPUT_INSTANCE_ID
                half4 vertex : POSITION;
                half3 normal : NORMAL;
                half4 uv : TEXCOORD0;
            };

            struct vertex_output
            {
                UNITY_VERTEX_INPUT_INSTANCE_ID
                half4 pos : SV_POSITION;
                half3 normal : NORMAL;
                half2 uv : TEXCOORD0;
                half4 pos_ws : TEXCOORD2;
                SHADOW_COORDS(3)
            };

            vertex_output vert(vertex_input v)
            {
                vertex_output o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.normal = normalize(mul(half4(v.normal, 0.0h), unity_WorldToObject).xyz);;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.pos_ws = mul(unity_ObjectToWorld, v.vertex);
                TRANSFER_SHADOW(o);
                return o;
            }

            UNITY_INSTANCING_BUFFER_START(InstanceProperties)
            UNITY_DEFINE_INSTANCED_PROP(half4, _Color)
            UNITY_INSTANCING_BUFFER_END(InstanceProperties)

            half4 frag(vertex_output i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);

                half3 light_direction_ws = _WorldSpaceLightPos0.xyz - i.pos_ws.xyz;
                half one_over_distance = 1.0h / length(light_direction_ws);
                half attenuation = lerp(1.0h, one_over_distance, _WorldSpaceLightPos0.w);

                half3 light_direction = _WorldSpaceLightPos0.xyz - i.pos_ws.xyz * _WorldSpaceLightPos0.w;
                half3 normal_direction = normalize(i.normal);
                half3 view_direction = normalize(_WorldSpaceCameraPos - i.pos_ws.xyz);

                half roughness = 0.2h; //_Roughness;
                half roughness_squared = roughness * roughness;
                half3 o_n_fraction = roughness_squared / (roughness_squared + half3(0.33h, 0.13h, 0.09h));
                half3 oren_nayar = half3(1.0h, 0.0h, 0.0h) + half3(-0.5h, 0.17h, 0.45h) * o_n_fraction;
                half cos_ndotl = saturate(dot(normal_direction, light_direction));
                half cos_ndotv = saturate(dot(normal_direction, view_direction));
                half oren_nayar_s = saturate(dot(light_direction, view_direction)) - cos_ndotl * cos_ndotv;
                oren_nayar_s /= lerp(max(cos_ndotl, cos_ndotv), 1.0h, step(oren_nayar_s, 0.0h));

                half3 surface_color = tex2D(_MainTex, i.uv * _MainTex_ST.xy + _MainTex_ST.zw);
                surface_color *= UNITY_ACCESS_INSTANCED_PROP(InstanceProperties, _Color).rgb;

                half3 lighting_model = _LightColor0.rgb * cos_ndotl * (oren_nayar.x + _LightColor0.rgb * oren_nayar.y +
                    oren_nayar.z * oren_nayar_s);
                half3 attenuation_color = attenuation * _LightColor0.rgb;
                half3 final_diffuse = lighting_model * attenuation_color;
                half shadow = SHADOW_ATTENUATION(i);
                half3 final_color = final_diffuse * surface_color * shadow;

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