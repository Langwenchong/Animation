// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/Kajiya-Kay"
{
    Properties{
        // 漫反射颜色，决定头发主色色调
        _DiffuseColor("Hair Diffuse Color",Color)= (1,1,1,1)
        // 主高光颜色
        _SpecularColor_1("Hair Primary Specular Color",Color)=(1,1,1,1)
        // 次高光颜色
        _SpecularColor_2("Hair Second Specular Color",Color)=(1,1,1,1)
        // 头发贴图模拟头发丝
        _BaseTex("BaseTexture",2D) = "white" {}
        // 高光偏移纹理
        _PrimaryShiftTex("PrimaryShiftTexture",2D)="white" {}
        _SecondShiftTex("SecondShiftTexture",2D)="white" {}
        // 透明渐变纹理
        _AlphaTex("AlphaTexture",2D) = "white" {}
        // 头发高光消融效果
        _SpecularWidth("Specular Width",Range(0,1))=1
        // 头发高光收敛
        _Specularity_1("Hair Primary Specularity",range(0,300))=20
        _Specularity_2("Hair Second Specularity",range(0,300))=20
        // 头发高光强度
        _SpecularScale("Hair Specular Scale",Range(0,2))=0.381
        // 高光偏移量
        _PrimaryShift("Primary Shift",Range(-5,5))=0
        _SecondShift("Second Shift",Range(-5,5))=0
        // 发现贴图
        _NormalMap("Nromal Map",2D)="white" {}
        // 设置凹凸程度
        _BumpScale("Hair Bump Scale",Range(0,10))=2
    }


    SubShader
    {
        LOD 200
        Pass{
            // 关闭面剔除
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            ZTest LEqual
            Cull off
            // 会调用计算光照
            Tags { "LightMode" = "ForwardBase" "Queue"="Transparent"}
            CGPROGRAM

            // 使用顶点与片元着色器
            #pragma vertex vert
            #pragma fragment frag

            // 需要引得库
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            

            struct appdata{
                // 顶点坐标，采样坐标，法线，切线
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f{
                // 采样坐标，裁剪顶点坐标（即MVP视口变换后的），法线，副切线，世界顶点坐标，切线空间到世界空间的转换矩阵
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD1;
                float3 bitangent : TEXCOORD2;
                float3 pos : TEXCOORD3;
                // 变换矩阵
                float4 TtoW0 : TEXCOORD4;
                float4 TtoW1 : TEXCOORD5;
                float4 TtoW2 : TEXCOORD6;
            };
            
            sampler2D _BaseTex;
            float4 _BaseTex_ST;
            sampler2D _AlphaTex;
            float4 _AlphaTex_ST;
            sampler2D _PrimaryShiftTex;
            float4 _PrimaryShiftTex_ST;
            sampler2D _SecondShiftTex;
            float4 _SecondShiftTex_ST;
            sampler2D _NormalMap;
            float4 _NormalMap_ST;

            float4 _DiffuseColor;
            float4 _SpecularColor_1;
            float4 _SpecularColor_2;
            fixed _SpecularWidth;
            fixed _SpecularScale;
            fixed _PrimaryShift;
            fixed _SecondShift;
            fixed _Specularity_1;
            fixed _Specularity_2;
            fixed _BumpScale;

            v2f vert(appdata v){
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv,_NormalMap);
                float3 worldPos=mul(unity_ObjectToWorld, v.vertex).xyz;
                float3 worldNormal=UnityObjectToWorldNormal(v.normal);
                float3 worldTangent=UnityWorldToObjectDir(v.tangent).xyz;
                float3 worldBitangent=cross(worldTangent,worldNormal)*v.tangent.w;
                o.pos = worldPos;
                o.normal=UnityObjectToWorldNormal(v.normal);
                o.bitangent =cross(v.normal,v.tangent.xyz)*v.tangent.w*unity_WorldTransformParams.w;
                o.TtoW0 = float4(worldTangent.x,worldBitangent.x,worldNormal.x,worldPos.x);
                o.TtoW1 = float4(worldTangent.y,worldBitangent.y,worldNormal.y,worldPos.y);
                o.TtoW2 = float4(worldTangent.z,worldBitangent.z,worldNormal.z,worldPos.z);
                return o;
            }

            half3 ShiftedTangent(float3 t,float3 n,float shift){
                // 偏移量，沿着头发丝方向
                return normalize(t+shift*n);
            }

            float StrandSpecular(float3 t,float3 v,float3 l,int exponent){
                // 使用半程向量与沿着头发丝的切线计算反射
                float3 h=normalize(l+v);
                float dotTH=dot(t,h);
                float sinTH=sqrt(1.0-dotTH*dotTH);
                // 边缘消融效果
                float dirAtten=smoothstep(-_SpecularWidth,0,dotTH);
                // 同时还收到收敛指数，高光强度模拟吸收
                return dirAtten*pow(sinTH,exponent)*_SpecularScale;
            }

            float3 HairSpecular(float3 t,float3 n,float3 l,float3 v,float2 uv){
                // 计算主高光与次高光的偏移量
                float shiftTex_1=tex2D(_PrimaryShiftTex,uv*_PrimaryShiftTex_ST.xy+_PrimaryShiftTex_ST.zw)-0.5;
                float3 t1=ShiftedTangent(t,n,_PrimaryShift+shiftTex_1);
                // 
                float3 specular1=_SpecularColor_1*StrandSpecular(t1,v,l,_Specularity_1);

                float shiftTex_2=tex2D(_SecondShiftTex,uv*_SecondShiftTex_ST.xy+_SecondShiftTex_ST.zw)-0.5;
                float3 t2=ShiftedTangent(t,n,_SecondShift+shiftTex_2);
                float3 specular2=_SpecularColor_2*StrandSpecular(t2,v,l,_Specularity_2);

                // 两者相加即为高光结果
                return specular1+specular2;

            }
            float3 HairDiffuse(float3 t,float3 l,float2 uv){
                // 同样需要使用切线与光线的sin计算
                float cosTL=dot(t,l);
                float sinTL=sqrt(1.0-cosTL*cosTL);
                return tex2D(_BaseTex,uv)*_DiffuseColor*sinTL;
            }
            
            float HairAlpha(float2 uv){
                // 读取灰度
                return tex2D(_AlphaTex,uv).r;
            }

            float3 getNormal(float4 TtoW0,float4 TtoW1,float4 TtoW2,float2 uv){
                // 采样发现，这里注意必须是设置为NromalMap
                float4 packedNormal = tex2D(_NormalMap,uv);
                //图片没有设置成normal map
                //float33 tangentNormal;
                //tangentNormal.xy = (packedNormal.xy * 2 - 1)*_BumpScale;
                //tangentNormal.z = sqrt(1 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
                // 解码得到采样后的切线坐标系下的发现
                float3 tangentNormal=UnpackNormal(packedNormal);
                tangentNormal.xy*=_BumpScale;
                // 需要转换为世界坐标系下的发现
                float3 worldNormal = normalize(float3(dot(TtoW0.xyz,tangentNormal),dot(TtoW1.xyz,tangentNormal),dot(TtoW2.xyz,tangentNormal)));
                return worldNormal;

            }
            fixed4 frag(v2f i) : SV_TARGET{
                float3 l=normalize(UnityWorldSpaceLightDir(i.pos));
                float3 v=normalize(UnityWorldSpaceViewDir(i.pos));
                float3 n=getNormal(i.TtoW0,i.TtoW1,i.TtoW2,i.uv);
                float3 b=normalize(i.bitangent);
                float3 diff=HairDiffuse(b,l,i.uv);
                float3 spec=HairSpecular(b,n,l,v,i.uv);
                // float4 col=float4(1,1,1,)*HairAlpha(i.uv);
                fixed4 col=fixed4(_LightColor0*(diff+spec),HairAlpha(i.uv));
                // fixed4 col=fixed4(_DiffuseColor);
                // fixed4 col=fixed4(HairAlpha(i.uv),HairAlpha(i.uv),HairAlpha(i.uv),HairAlpha(i.uv));
                return col;
            }
            ENDCG
        }
         Pass{
            // 关闭面剔除
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite On
            ZTest LEqual
            Cull Back
            // 会调用计算光照
            Tags { "LightMode" = "ForwardBase" "Queue"="Transparent"}
            CGPROGRAM

            // 使用顶点与片元着色器
            #pragma vertex vert
            #pragma fragment frag

            // 需要引得库
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            

            struct appdata{
                // 顶点坐标，采样坐标，法线，切线
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f{
                // 采样坐标，裁剪顶点坐标（即MVP视口变换后的），法线，副切线，世界顶点坐标，切线空间到世界空间的转换矩阵
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD1;
                float3 bitangent : TEXCOORD2;
                float3 pos : TEXCOORD3;
                // 变换矩阵
                float4 TtoW0 : TEXCOORD4;
                float4 TtoW1 : TEXCOORD5;
                float4 TtoW2 : TEXCOORD6;
            };
            
            sampler2D _BaseTex;
            float4 _BaseTex_ST;
            sampler2D _AlphaTex;
            float4 _AlphaTex_ST;
            sampler2D _PrimaryShiftTex;
            float4 _PrimaryShiftTex_ST;
            sampler2D _SecondShiftTex;
            float4 _SecondShiftTex_ST;
            sampler2D _NormalMap;
            float4 _NormalMap_ST;

            float4 _DiffuseColor;
            float4 _SpecularColor_1;
            float4 _SpecularColor_2;
            fixed _SpecularWidth;
            fixed _SpecularScale;
            fixed _PrimaryShift;
            fixed _SecondShift;
            fixed _Specularity_1;
            fixed _Specularity_2;
            fixed _BumpScale;

            v2f vert(appdata v){
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv,_NormalMap);
                float3 worldPos=mul(unity_ObjectToWorld, v.vertex).xyz;
                float3 worldNormal=UnityObjectToWorldNormal(v.normal);
                float3 worldTangent=UnityWorldToObjectDir(v.tangent).xyz;
                float3 worldBitangent=cross(worldTangent,worldNormal)*v.tangent.w;
                o.pos = worldPos;
                o.normal=UnityObjectToWorldNormal(v.normal);
                o.bitangent =cross(v.normal,v.tangent.xyz)*v.tangent.w*unity_WorldTransformParams.w;
                o.TtoW0 = float4(worldTangent.x,worldBitangent.x,worldNormal.x,worldPos.x);
                o.TtoW1 = float4(worldTangent.y,worldBitangent.y,worldNormal.y,worldPos.y);
                o.TtoW2 = float4(worldTangent.z,worldBitangent.z,worldNormal.z,worldPos.z);
                return o;
            }

            half3 ShiftedTangent(float3 t,float3 n,float shift){
                // 偏移量，沿着头发丝方向
                return normalize(t+shift*n);
            }

            float StrandSpecular(float3 t,float3 v,float3 l,int exponent){
                // 使用半程向量与沿着头发丝的切线计算反射
                float3 h=normalize(l+v);
                float dotTH=dot(t,h);
                float sinTH=sqrt(1.0-dotTH*dotTH);
                // 边缘消融效果
                float dirAtten=smoothstep(-_SpecularWidth,0,dotTH);
                // 同时还收到收敛指数，高光强度模拟吸收
                return dirAtten*pow(sinTH,exponent)*_SpecularScale;
            }

            float3 HairSpecular(float3 t,float3 n,float3 l,float3 v,float2 uv){
                // 计算主高光与次高光的偏移量
                float shiftTex_1=tex2D(_PrimaryShiftTex,uv*_PrimaryShiftTex_ST.xy+_PrimaryShiftTex_ST.zw)-0.5;
                float3 t1=ShiftedTangent(t,n,_PrimaryShift+shiftTex_1);
                // 
                float3 specular1=_SpecularColor_1*StrandSpecular(t1,v,l,_Specularity_1);

                float shiftTex_2=tex2D(_SecondShiftTex,uv*_SecondShiftTex_ST.xy+_SecondShiftTex_ST.zw)-0.5;
                float3 t2=ShiftedTangent(t,n,_SecondShift+shiftTex_2);
                float3 specular2=_SpecularColor_2*StrandSpecular(t2,v,l,_Specularity_2);

                // 两者相加即为高光结果
                return specular1+specular2;

            }
            float3 HairDiffuse(float3 t,float3 l,float2 uv){
                // 同样需要使用切线与光线的sin计算
                float cosTL=dot(t,l);
                float sinTL=sqrt(1.0-cosTL*cosTL);
                return tex2D(_BaseTex,uv)*_DiffuseColor*sinTL;
            }
            
            float HairAlpha(float2 uv){
                // 读取灰度
                return tex2D(_AlphaTex,uv).r;
            }

            float3 getNormal(float4 TtoW0,float4 TtoW1,float4 TtoW2,float2 uv){
                // 采样发现，这里注意必须是设置为NromalMap
                float4 packedNormal = tex2D(_NormalMap,uv);
                //图片没有设置成normal map
                //float33 tangentNormal;
                //tangentNormal.xy = (packedNormal.xy * 2 - 1)*_BumpScale;
                //tangentNormal.z = sqrt(1 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
                // 解码得到采样后的切线坐标系下的发现
                float3 tangentNormal=UnpackNormal(packedNormal);
                tangentNormal.xy*=_BumpScale;
                // 需要转换为世界坐标系下的发现
                float3 worldNormal = normalize(float3(dot(TtoW0.xyz,tangentNormal),dot(TtoW1.xyz,tangentNormal),dot(TtoW2.xyz,tangentNormal)));
                return worldNormal;

            }
            fixed4 frag(v2f i) : SV_TARGET{
                float3 l=normalize(UnityWorldSpaceLightDir(i.pos));
                float3 v=normalize(UnityWorldSpaceViewDir(i.pos));
                float3 n=getNormal(i.TtoW0,i.TtoW1,i.TtoW2,i.uv);
                float3 b=normalize(i.bitangent);
                float3 diff=HairDiffuse(b,l,i.uv);
                float3 spec=HairSpecular(b,n,l,v,i.uv);
                // float4 col=float4(1,1,1,)*HairAlpha(i.uv);
                fixed4 col=fixed4(_LightColor0*(diff+spec),HairAlpha(i.uv));
                // fixed4 col=fixed4(_DiffuseColor);
                // fixed4 col=fixed4(HairAlpha(i.uv),HairAlpha(i.uv),HairAlpha(i.uv),HairAlpha(i.uv));
                return col;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
