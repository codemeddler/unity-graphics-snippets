Shader "Post Process/PreCompose"
{
    Properties
    {
        _MainTex("Main Texture", 2D) = "black" {}
        _BloomTex("Bloom", 2D) = "black" {}
        _BloomIntensity("Bloom Intensity", float) = 0.672
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

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = v.vertex;
                o.uv = v.uv;

                if (_ProjectionParams.x < 0.0h)
                {
                    o.uv.y = 1.0h - o.uv.y;
                }

                return o;
            }

            sampler2D_half _BloomTex, _MainTex;
            half4 _BloomTint;
            half _BloomIntensity;

            half4 frag(v2f i) : SV_Target
            {
                half3 main_color = tex2D(_MainTex, i.uv).rgb;

                half3 alpha_multiplier = half3(1.0h, 1.0h, 1.0h);

                half4 raw_bloom = tex2D(_BloomTex, i.uv);
                half raw_bloom_intensity = dot(raw_bloom.rgb, half3(0.2126h, 0.7152h, 0.0722h));
                half3 bloom = raw_bloom * _BloomIntensity * _BloomTint;
                main_color = main_color + bloom;
                alpha_multiplier *= bloom;

                half4 result = half4(alpha_multiplier, 1.0h);
                return result;
            }
            ENDCG
        }
    }
}