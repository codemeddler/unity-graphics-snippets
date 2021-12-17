Shader "Post Process/Compose"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _PreComposeTex("PreCompose Texture", 2D) = "black" {}
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            struct appdata
            {
                half4 vertex : POSITION;
                half2 uv : TEXCOORD0;
            };

            struct v2f
            {
                half4 vertex : SV_POSITION;
                half2 uv : TEXCOORD0;
            };

            half4 _MainTex_TexelSize;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = v.vertex;
                o.uv = v.uv;

                if (_ProjectionParams.x < 0.0h)
                {
                    o.uv.y = 1.0h - v.uv.y;
                }

                #if UNITY_UV_STARTS_AT_TOP
                if (_MainTex_TexelSize.y < 0.0h)
                {
                    o.uv.y = 1.0h - v.uv.y;
                }
                #endif

                return o;
            }

            sampler2D_half _MainTex, _PreComposeTex;

            half4 frag(v2f i) : SV_Target
            {
                half4 pre_compose = tex2D(_PreComposeTex, i.uv);
                half4 col = tex2D(_MainTex, i.uv);
                half3 main_color = col.rgb * pre_compose.a + pre_compose.rgb;

                half3 result = main_color;

                return half4(result, 1.0h);
            }
            ENDCG
        }
    }
}