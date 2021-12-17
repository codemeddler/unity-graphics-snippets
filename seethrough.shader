Shader "Custom/seethrough"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Solid Color", Color) = (0.0, 0.0, 0.0, 1.0)
    }
    SubShader
    {
        Tags
        {
            "Queue"="Transparent"
        }
        Pass
        {
            Tags
            {
                "IgnoreProjector" = "True"
                "RenderType" = "Transparent"
            }
            ZWrite Off 
            Cull Back
            Blend SrcAlpha OneMinusSrcAlpha
            CGPROGRAM
            #pragma vertex vert alpha
            #pragma fragment frag alpha
            #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight
            #pragma multi_compile_instancing
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"

            sampler2D _MainTex;
            half4 _MainTex_ST;
            
            struct vertex_input
            {
                UNITY_VERTEX_INPUT_INSTANCE_ID
                half4 vertex : POSITION;
                half4 uv : TEXCOORD0;
            };

            struct vertex_output
            {
                UNITY_VERTEX_INPUT_INSTANCE_ID
                half4 pos : SV_POSITION;
                half2 uv : TEXCOORD0;
            };

            vertex_output vert(vertex_input v)
            {
                vertex_output o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            UNITY_INSTANCING_BUFFER_START(InstanceProperties)
            UNITY_DEFINE_INSTANCED_PROP(half4, _Color)
            UNITY_INSTANCING_BUFFER_END(InstanceProperties)

            half4 frag(vertex_output i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                half4 surface_color = tex2D(_MainTex, i.uv * _MainTex_ST.xy + _MainTex_ST.zw);
                surface_color *= UNITY_ACCESS_INSTANCED_PROP(InstanceProperties, _Color);
                return surface_color;
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