Shader "Custom/car"
{
    Properties
    {
        _MainTex ("Pattern", 2D) = "white" {}
        _Color ("Color", Color) = (1, 1, 1, 1)
        _Shininess ("Shininess", Float) = 10.0
        _SpecColor ("Specular Color", Color) = (1.0, 1.0, 1.0, 1.0)
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
                half4 tangent : TANGENT;
                half2 uv : TEXCOORD0;
            };

            struct vertex_output
            {
                UNITY_VERTEX_INPUT_INSTANCE_ID
                half4 pos : POSITION;
                half3 normal : NORMAL;
                half2 uv : TEXCOORD0;
                half4 pos_ws : TEXCOORD1;
                half3 reflection_ws: TEXCOORD2;
                half3 tangent : TEXCOORD3;
                half3 vertex_light : TEXCOORD4;
                SHADOW_COORDS(5)
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

                half3 world_view_dir = normalize(UnityWorldSpaceViewDir(o.pos_ws));
                half3 world_normal = UnityObjectToWorldNormal(v.normal);

                o.reflection_ws = reflect(-world_view_dir, world_normal);
                o.tangent = normalize(mul(unity_ObjectToWorld, half4(v.tangent.xyz, 0.0h)).xyz);
                o.vertex_light = Shade4PointLights(
                    unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
                    unity_LightColor[0].rgb, unity_LightColor[1].rgb,
                    unity_LightColor[2].rgb, unity_LightColor[3].rgb,
                    unity_4LightAtten0, o.pos_ws, o.normal
                );
                TRANSFER_SHADOW(o)
                return o;
            }

            UNITY_INSTANCING_BUFFER_START(InstanceProperties)
            UNITY_DEFINE_INSTANCED_PROP(half4, _Color)
            UNITY_DEFINE_INSTANCED_PROP(half4, _SpecColor)
            UNITY_DEFINE_INSTANCED_PROP(half, _Shininess)
            UNITY_INSTANCING_BUFFER_END(InstanceProperties)

            half4 frag(vertex_output i) : COLOR
            {
                UNITY_SETUP_INSTANCE_ID(i);
                half4 sky_data = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, i.reflection_ws);

                half3 normal_direction = normalize(i.normal);
                half3 view_direction = normalize(_WorldSpaceCameraPos - i.pos_ws.xyz);
                half3 light_direction = _WorldSpaceLightPos0.xyz - i.pos_ws.xyz * _WorldSpaceLightPos0.w;
                half3 light_direction_ws = _WorldSpaceLightPos0.xyz - i.pos_ws.xyz;

                half one_over_distance = 1.0h / length(light_direction_ws);
                half attenuation = lerp(1.0h, one_over_distance, _WorldSpaceLightPos0.w);

                half3 surface_color = tex2D(_MainTex, i.uv * _MainTex_ST.xy + _MainTex_ST.zw);
                surface_color *= UNITY_ACCESS_INSTANCED_PROP(InstanceProperties, _Color).rgb;
                half3 ambient_lighting = ShadeSH9(half4(normal_direction, 1.0h));
                half3 diffuse_reflection = attenuation * _LightColor0.rgb * saturate(dot(normal_direction, light_direction));
                half3 specular_reflection;

                if (dot(i.normal, light_direction) < 0.0h)
                {
                    specular_reflection = half3(0.0h, 0.0h, 0.0h);
                }
                else
                {
                    half3 halfway_vector = normalize(light_direction + view_direction);
                    half3 bi_normal_direction = cross(normal_direction, i.tangent);

                    half dot_ln = dot(light_direction, normal_direction);
                    half dot_hn = dot(halfway_vector, normal_direction);
                    half dot_vn = dot(view_direction, normal_direction);
                    half dot_ht_alpha_x = dot(halfway_vector, i.tangent) / UNITY_ACCESS_INSTANCED_PROP(
                        InstanceProperties, _Shininess);
                    half dot_hb_alpha_y = dot(halfway_vector, bi_normal_direction) / UNITY_ACCESS_INSTANCED_PROP(
                        InstanceProperties, _Shininess);

                    specular_reflection =
                        attenuation *
                        _LightColor0.rgb *
                        UNITY_ACCESS_INSTANCED_PROP(InstanceProperties, _SpecColor).rgb *
                        sqrt(max(0.0h, dot_ln / dot_vn)) *
                        exp(-2.0h * (dot_ht_alpha_x * dot_ht_alpha_x + dot_hb_alpha_y * dot_hb_alpha_y) / (1.0h + dot_hn
                        ));
                }

                half shadow = SHADOW_ATTENUATION(i);
                half3 sky_color = DecodeHDR(sky_data, unity_SpecCube0_HDR);
                //diffuse_reflection *= 1.0h - specular_reflection.rgb;
                half3 color = ambient_lighting * surface_color * sky_color + diffuse_reflection * shadow * sky_color * surface_color +
                    specular_reflection * shadow * sky_color + i.vertex_light;

                return half4(color, 1.0h);
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
                half4 tangent : TANGENT;
                half2 uv : TEXCOORD0;
            };

            struct vertex_output
            {
                UNITY_VERTEX_INPUT_INSTANCE_ID
                half4 pos : POSITION;
                half3 normal : NORMAL;
                half2 uv : TEXCOORD0;
                half4 pos_ws : TEXCOORD1;
                half3 reflection_ws: TEXCOORD2;
                half3 tangent : TEXCOORD3;
                SHADOW_COORDS(4)
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
                half3 world_view_dir = normalize(UnityWorldSpaceViewDir(o.pos_ws));
                half3 world_normal = UnityObjectToWorldNormal(v.normal);
                o.reflection_ws = reflect(-world_view_dir, world_normal);
                o.tangent = normalize(mul(unity_ObjectToWorld, half4(v.tangent.xyz, 0.0h)).xyz);
                TRANSFER_SHADOW(o)
                return o;
            }

            UNITY_INSTANCING_BUFFER_START(InstanceProperties)
            UNITY_DEFINE_INSTANCED_PROP(half4, _Color)
            UNITY_DEFINE_INSTANCED_PROP(half4, _SpecColor)
            UNITY_DEFINE_INSTANCED_PROP(half, _Shininess)
            UNITY_INSTANCING_BUFFER_END(InstanceProperties)

            half4 frag(vertex_output i) : COLOR
            {
                UNITY_SETUP_INSTANCE_ID(i);
                half4 sky_data = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, i.reflection_ws);
                half3 normal_direction = normalize(i.normal);
                half3 view_direction = normalize(_WorldSpaceCameraPos - i.pos_ws.xyz);
                half3 light_direction_ws = _WorldSpaceLightPos0.xyz - i.pos_ws.xyz;
                half one_over_distance = 1.0h / length(light_direction_ws);
                half attenuation = lerp(1.0h, one_over_distance, _WorldSpaceLightPos0.w);

                half3 light_direction = _WorldSpaceLightPos0.xyz - i.pos_ws.xyz * _WorldSpaceLightPos0.w;
                half3 surface_color = tex2D(_MainTex, i.uv) * UNITY_ACCESS_INSTANCED_PROP(InstanceProperties, _Color).
                    rgb;
                half3 diffuse_reflection = attenuation * _LightColor0.rgb * max(
                    0.0h, dot(normal_direction, light_direction));
                half3 specular_reflection;

                if (dot(i.normal, light_direction) < 0.0h)
                {
                    specular_reflection = half3(0.0h, 0.0h, 0.0h);
                }
                else
                {
                    half3 halfway_vector = normalize(light_direction + view_direction);
                    half3 bi_normal_direction = cross(normal_direction, i.tangent);
                    half dot_ln = dot(light_direction, normal_direction);
                    half dot_hn = dot(halfway_vector, normal_direction);
                    half dot_vn = dot(view_direction, normal_direction);
                    half dot_ht_alpha_x = dot(halfway_vector, i.tangent) / UNITY_ACCESS_INSTANCED_PROP(
                        InstanceProperties, _Shininess);
                    half dot_hb_alpha_y = dot(halfway_vector, bi_normal_direction) / UNITY_ACCESS_INSTANCED_PROP(
                        InstanceProperties, _Shininess);

                    specular_reflection =
                        attenuation *
                        _LightColor0.rgb *
                        UNITY_ACCESS_INSTANCED_PROP(InstanceProperties, _SpecColor).rgb *
                        sqrt(max(0.0h, dot_ln / dot_vn)) *
                        exp(-2.0h * (dot_ht_alpha_x * dot_ht_alpha_x + dot_hb_alpha_y * dot_hb_alpha_y) / (1.0h + dot_hn
                        ));
                }

                half shadow = SHADOW_ATTENUATION(i);
                half3 sky_color = DecodeHDR(sky_data, unity_SpecCube0_HDR);
                diffuse_reflection *= 1.0h - specular_reflection.rgb;
                half3 color = (diffuse_reflection * shadow * sky_color) * surface_color +
                    specular_reflection * shadow * sky_color;

                return half4(color, 1.0h);
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

            struct vertex_output
            {
                UNITY_VERTEX_INPUT_INSTANCE_ID
                V2F_SHADOW_CASTER;
            };

            UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
            UNITY_INSTANCING_BUFFER_END(Props)

            vertex_output vert(appdata_base v)
            {
                vertex_output o;
                UNITY_SETUP_INSTANCE_ID(v);
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                return o;
            }

            half4 frag(vertex_output i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }
    }
}