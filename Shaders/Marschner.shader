Shader "Custom/Marschner"
{
    Properties
    {    
        // 头发主色调
        [HDR]_DiffuseColor("Hair Diffuse Color",Color)= (1,1,1,1)
        // 主高光颜色
        _SpecularColor_1("Hair Primary Specular Color",Color)=(1,1,1,1)
        // 次高光颜色
        _SpecularColor_2("Hair Second Specular Color",Color)=(1,1,1,1)
        // 高光偏移纹理
        _PrimaryShiftTex("PrimaryShiftTexture",2D)="white" {}
        _SecondShiftTex("SecondShiftTexture",2D)="white" {}
        // 基础反射率与纹理
        _MainTex("Main Tex",2D)= "white" {}
        // 灰度渐变
        _AlphaTex("Alpha Tex",2D) = "black" {}
        // 环境光遮蔽增加阴影效果
        _AoTex("Ao Tex",2D) = "white" {}
        // 粗糙度
        _RoughnessTex("Roughness Tex",2D)="white" {}
        // 散射能力
        _EmissionTex("Emission Tex",2D)="white" {}
        // 金属度
        _Metallic("Metallic Tex",2D)="white" {}
        // 法线贴图
        _NormalMap("Nromal Map",2D) = "white" {}
        // 设置凹凸程度
        _BumpScale("Hair Bump Scale",Range(0,10))=0.2
        // 偏移量
        _Shift("Specular Shift Scale",Range(0,1))=0.04
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
    }
    SubShader
    {
        LOD 200
        Pass{
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            ZTest LEqual
            Cull Off
            // 会调用计算光照
            Tags {"RenderType"="Transparent" "LightMode" = "ForwardBase" "Queue"="Transparent"}

            CGPROGRAM

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            // pbr光照需要
            #include "UnityPBSLighting.cginc"
            #include "AutoLight.cginc"

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog


            struct appdata{
                // 顶点坐标，采样坐标，发现，切线
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 texcoord1 : TEXCOORD1;
                float4 tangent : TANGENT;
            };

            struct v2f{
                // 裁剪坐标，采样坐标，法线，副切线，世界坐标，切线空间转世界空间的矩阵
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float3 bitangent :TEXCOORD2;
                float3 worldPos : TEXCOORD3;
                // 变换矩阵
                float4 TtoW0 : TEXCOORD4;
                float4 TtoW1 : TEXCOORD5;
                float4 TtoW2 : TEXCOORD6;

                // 光照贴图阴影坐标
                UNITY_SHADOW_COORDS(7)
                UNITY_FOG_COORDS(8)
            };

            struct SurfaceOutputHair{
                // 会使用的头发性质，反射率，法线，粗糙度，光照吸收模拟环境光遮蔽，透明度，离心率，金属度，高光偏移量
                half3 Albedo;
                half3 Normal;
                half Roughness;
                half AO;
                half Alpha;
                half3 Emission;
                half Metallic;
                half Shift;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _AlphaTex;
            float4 _AlphaTex_ST;
            sampler2D _AoTex;
            sampler2D _RoughnessTex;
            sampler2D _EmissionTex;
            sampler2D _MetallicTex;
            sampler2D _NormalMap;

            float4 _DiffuseColor;
            fixed _Shift;
            fixed _BumpScale;

            // π和π^0.5，主要是加速计算
            #define PI 3.1415926
            #define SQRT2PI 2.50663

            v2f vert(appdata v){
                v2f o;
                UNITY_INITIALIZE_OUTPUT(v2f, o);//初始化归零
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv,_AlphaTex);
                float3 worldPos=mul(unity_ObjectToWorld, v.vertex).xyz;
                float3 worldNormal=UnityObjectToWorldNormal(v.normal);
                float3 worldTangent=UnityWorldToObjectDir(v.tangent).xyz;
                float3 worldBitangent=cross(worldTangent,worldNormal)*v.tangent.w;
                o.worldPos = worldPos;
                o.normal=UnityObjectToWorldNormal(v.normal);
                o.bitangent =cross(v.normal,v.tangent.xyz)*v.tangent.w*unity_WorldTransformParams.w;
                o.TtoW0 = float4(worldTangent.x,worldBitangent.x,worldNormal.x,worldPos.x);
                o.TtoW1 = float4(worldTangent.y,worldBitangent.y,worldNormal.y,worldPos.y);
                o.TtoW2 = float4(worldTangent.z,worldBitangent.z,worldNormal.z,worldPos.z);
                // 光照贴图纹理坐标
                UNITY_TRANSFER_LIGHTING(o,v.texcoord1.xy);
                return o;
            }

            // 采样法线贴图获取法线
            float3 getNormal(float4 TtoW0,float4 TtoW1,float4 TtoW2,float2 uv){
                // 采样发现，这里注意必须是设置为NromalMap
                float4 packedNormal = tex2D(_NormalMap,uv);
                //图片没有设置成normal map
                //float33 tangentNormal;
                //tangentNormal.xy = (packedNormal.xy * 2 - 1)*_BumpScale;
                //tangentNormal.z = sqrt(1 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
                // 解码得到采样后的切线坐标系下的法线
                float3 tangentNormal=UnpackNormal(packedNormal);
                tangentNormal.xy*=_BumpScale;
                // 需要转换为世界坐标系下的法线
                float3 worldNormal = normalize(float3(dot(TtoW0.xyz,tangentNormal),dot(TtoW1.xyz,tangentNormal),dot(TtoW2.xyz,tangentNormal)));
                return worldNormal;

            }

            inline float square(float x){
                // 不用pow加速计算
                return x*x;
            }

            // M项使用的高斯分布计算式
            float Hair_g(float B,float Theta){
                return exp(-0.5 * square(Theta) / (B * B)) / (SQRT2PI * B);
            }

            // 菲涅尔项
            inline float3 SpecularFresnel(float F0, float x) {
                return F0 + (1.0f - F0) * pow(1 - x, 5);
            }

            // 核心公式，计算BSDF，这里采用UE类似的模拟加速计算，参考文章：
            // [Marschner et al. 2003, "Light Scattering from Human Hair Fibers"]
            // [Pekelis et al. 2015, "A Data-Driven Light Scattering Model for Hair"]
            float3 HairSpecularMarschner(SurfaceOutputHair sh,float3 N,float3 V,float3 L,float Shadow,float Backlit,float Area){
                float3 S = 0;
                const float dotVL = dot(V,L);
                const float SinThetaL = clamp(dot(N,L),-1.f,1.f);
                const float SinThetaV = clamp(dot(N,V),-1.f,1.f);
                float CosThetaL = sqrt(max(0,1-SinThetaL*SinThetaL));
                float CosThetaV = sqrt(max(0,1-SinThetaV*SinThetaV));
                float CosThetaD = sqrt((1 + CosThetaL * CosThetaV + SinThetaL * SinThetaV) / 2.0);

                const float3 Lp = L-SinThetaL*N;
                const float3 Vp = V-SinThetaV*N;
                const float CosPhi = dot(Lp,Vp)*rsqrt(dot(Lp,Lp)*dot(Vp,Vp) + 1e-4);
                const float CosHalfPhi = sqrt(saturate(0.5+0.5*CosPhi));

                /**
                * η'的拟合
                * 原型：η' = sqrt( η * η - 1 + CosThetaD^2) / CosThetaD;
                * float n_prime = sqrt( n*n - 1 + Pow2( CosThetaD ) ) / CosThetaD;
                * 拟合思路：η即人类发丝折射率写死为1.55, 拟合后的η'如下：
                * η' = 1.19 / CosThetaD + 0.36 * CosThetaD;
                */
                float n=1.55;
                float n_prime = 1.19/CosThetaD+0.36*CosThetaD;

                float Shift=sh.Shift;
                float Alpha[] = {
                    -Shift*2,
                    Shift,
                    Shift*4
                };

                float B[]={
                    Area+square(sh.Roughness),
                    Area+square(sh.Roughness)/2,
                    Area+square(sh.Roughness)*2
                };

                float F0=square((1-n)/(1+n));

                float3 Tp;
                float Mp,Np,A,f,Fp,h,a;

                // R
                // N_R\left(\theta_i, \theta_r, \phi\right)=\left(\frac{1}{4} \Cos \frac{\phi}{2}\right) A(0, h)
                Mp=Hair_g(B[0],SinThetaL+SinThetaV-Alpha[0]);
                A=SpecularFresnel(F0,sqrt(saturate(0.5 + 0.5 * dotVL)));
                Np=0.25*CosHalfPhi*A;
                S+=Mp*Np*lerp(1,Backlit,saturate(-dotVL));
                // S+= Mp;

                // TT
                /**
                * Step1: 对h的拟合
                * h的原型计算公式如下：
                * float h = CosHalfPhi * rsqrt( 1 + a*a - 2*a * sqrt( 0.5 - 0.5 * CosPhi ) );
                * float h = CosHalfPhi * ( ( 1 - Pow2( CosHalfPhi ) ) * a + 1 );
                *
                * 最终曲线拟合完的h_tt如下：
                */
                Mp=Hair_g(B[1],SinThetaL+SinThetaV-Alpha[1]);
                a=1/n_prime;
                h=CosHalfPhi*(1+a*(0.6 - 0.8 * CosPhi));
                
                /**
                * Step2：η'的拟合
                * 原型：η' = sqrt( η * η - 1 + CosThetaD^2) / CosThetaD;
                * 拟合思路：η即人类发丝折射率写死为1.55, 拟合后的η'如下：
                * η' = 1.19 / CosThetaD + 0.36 * CosThetaD;
                * 代码往上翻
                */
                f=SpecularFresnel(F0,CosThetaD*sqrt(saturate(1 - h*h)));
                Fp=square(1 - f);

                /**
                * Step3：对于吸收项T的拟合：选择Pixar的方案但没有直接用，还是做了拟合
                *
                * T与γ_t的计算原型如下：
                * T(θ，φ) = e^{-2 * μ_a * (1 + Cos(2γ_t)) / (Cosθt)}，其中γt = sin^-1(h / η')
                * 代码实现：float yi = asinFast(h); float yt = asinFast(h / n_prime);
                * 
                * 参考Pixar的实现：
                * T(θ，φ) = e^{-epsilo(C) * Cosγt / Cosθd}
                * 代码实现：float3 Tp = pow( GBuffer.BaseColor, 0.5 * ( 1 + Cos(2*yt) ) / CosThetaD );
                */
                // 这里C直接使用折射率进一步简化
                Tp = pow(sh.Albedo, 0.5 * sqrt(1 - square((h * a))) / CosThetaD);
                /**
                * Step4: 对分布项D的拟合
                * 技术原型：Pixar's Logistic Distribution Function
                * D(φ，s, μ) = (e^{(φ - μ) / s}) / (s^{1 + e^{(φ - μ) / s}}^2)
                * 
                * 考虑s_tt实际上贡献很小，因此近似如下：
                * D_TT(φ) = D(φ，0.35，Π) ≈ e^{-3.65Cosφ - 3.98}
                */
                Np=exp(-3.65*CosPhi-3.98);
                S+=Mp*Np*Fp*Tp*Backlit;
                // S+=Mp;

                // TRT
                /**
                * Step1 ：对h的拟合
                * h_trt = sqrt(3) / 2
                * float h = 0.75;
                */
                Mp=Hair_g(B[2],SinThetaL+SinThetaV-Alpha[2]);
                f=SpecularFresnel(F0,CosThetaD*0.5f);
                Fp=square(1 - f)*f;
                
                /**
                * Step2：对于吸收项T的拟合
                * T_TRT(θ，φ) = C^{0.8 / Cosθd}
                */
                Tp=pow(sh.Albedo,0.8/CosThetaD);
                Np=exp(17*CosPhi-16.78);
                S+=Mp*Np*Fp*Tp;
                // S+=Mp;
                
                return S;
            }

            // Kajiya推导的解析解，主要是模拟头发间的散射
            float3 HairDiffuseKajiya(SurfaceOutputHair sh,float3 N,float3 V,float3 L,float Shadow,float Backlit,float Area){
                float3 S = 0;
                float KajiyaDiffuse = 1-abs(dot(N,L));

                float3 FakeNormal = normalize(V-N*dot(V,N));
                N=FakeNormal;

                // Hack approximation for multiple scattering.
                float Wrap=1;
                float dotNL=saturate((dot(N,L)+Wrap)/square(1+Wrap));
                float DiffuseScatter=( (1 / PI) * lerp(dotNL, KajiyaDiffuse, 0.33))*sh.Metallic;
                float Luma=Luminance(sh.Albedo);
                float3 ScatterTint=pow(sh.Albedo/Luma,1 - Shadow);
                S=sqrt(sh.Albedo)*DiffuseScatter*ScatterTint;

                return S;
            }

            float3 HairShading(SurfaceOutputHair sh,float3 N,float3 V,float3 L,float Shadow,float Backlit,float Area){
                float3 S= float3(0,0,0);
                // add Specualr
                S=HairSpecularMarschner(sh,N,V,L,Shadow,Backlit,Area);
                // add Diffuse
                S+=HairDiffuseKajiya(sh,N,V,L,Shadow,Backlit,Area);
                // 校验一下，保证S不会小于零
                S=-min(-S,0.0);
                return S;
            }

            float3 HairBxDF(SurfaceOutputHair sh,float3 N,float3 V,float3 L,float Shadow,float Backlit,float Area){
                // 这里sh提供表面材质属性，Shadow提供头发之间的阴影遮蔽强度，Backlit影响透光强度，Area决定散射强度
                return HairShading(sh,N,V,L,Shadow,Backlit,Area);
            }

            inline void  LightingHair_GI(SurfaceOutputHair sh,UnityGIInput giInput,inout UnityGI gi){
                // 计算全局光照效果，会更新gi中的light和diffuse参数，参考了giInput,法线和环境光遮蔽生成
                gi=UnityGlobalIllumination(giInput,sh.AO,sh.Normal);
            }

            inline fixed4 LightingHair(SurfaceOutputHair sh,float3 viewDir,UnityGI gi){
                fixed4 c = fixed4(0,0,0,sh.Alpha);
                // 直接光照，由于光照直射强度高，所以是提供透射的主要因素，但是散射能力弱
                c.rgb=gi.light.color*HairBxDF(sh,sh.Normal,viewDir,gi.light.dir,0.4f,1.0f,0.0f);
                // 间接光照，基本不提供透射，但是简介光照主要提供表面散射，是头发暗部底色的主要贡献
                float3 reflect=normalize(viewDir-sh.Normal*dot(sh.Normal,viewDir));
                // 此时贡献光源不是来自灯光，而是根据视线反射对应的反射处，别忘了乘直径
                c.rgb+=gi.indirect.diffuse*6.28f*HairBxDF(sh,sh.Normal,viewDir,reflect,0.1f,0.0f,0.5f);

                return c;
            }

            fixed4 frag(v2f i) : SV_TARGET{
                float3 l=normalize(UnityWorldSpaceLightDir(i.worldPos));
                float3 v=normalize(UnityWorldSpaceViewDir(i.worldPos));
                // float3 n=getNormal(i.TtoW0,i.TtoW1,i.TtoW2,i.uv);
                float3 n = normalize(i.normal);

                float3 albedo = tex2D(_MainTex,i.uv);
                float ao =tex2D(_AoTex,i.uv);
                float alpha=tex2D(_AlphaTex,i.uv).r;
                float roughness=tex2D(_RoughnessTex,i.uv);
                float metallic=tex2D(_MetallicTex,i.uv).a;
                float3 emission=tex2D(_EmissionTex,i.uv);

                SurfaceOutputHair sh;
                UNITY_INITIALIZE_OUTPUT(SurfaceOutputHair, sh);//初始化归零
                sh.Normal=n;
                sh.AO=ao;
                sh.Albedo = fixed4(albedo*_DiffuseColor,alpha); 
                sh.Roughness=roughness;
                sh.Emission=emission;
                sh.Alpha=alpha;
                sh.Metallic=metallic;
                sh.Shift=_Shift;

                // compute lighting & shadowing factor
                //计算光照衰减和阴影
                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos)

                // 计算全局光照
                UnityGI gi;
                UNITY_INITIALIZE_OUTPUT(UnityGI, gi);//初始化归零
                gi.indirect.diffuse=0;
                gi.indirect.specular=0;
                gi.light.color = _LightColor0.rgb;
                gi.light.dir=l;

                UnityGIInput giInput;
                UNITY_INITIALIZE_OUTPUT(UnityGIInput, giInput);//初始化归零
                giInput.light=gi.light;
                giInput.worldPos=i.worldPos;
                giInput.worldViewDir=v;
                giInput.atten=atten;
                giInput.probeHDR[0]=unity_SpecCube0_HDR;
                giInput.probeHDR[1]=unity_SpecCube1_HDR;

                // 计算全局光照
                LightingHair_GI(sh,giInput,gi);
                // 计算最终颜色值
                fixed4 col = LightingHair(sh,v,gi);
                // fixed4 col = fixed4(gi.light.color,1.0);
                // fixed4 col=fixed4(n.r,n.g,n.b,1.0);
                // fixed4 col=fixed4(sh.Alpha,sh.Alpha,sh.Alpha,sh.Alpha);
                clip(col.a-0.2f);
                return col;
            }   
            ENDCG
        }
        Pass{
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite On
            ZTest LEqual
            Cull Back
            // 会调用计算光照
            Tags {"RenderType"="Transparent" "LightMode" = "ForwardBase" "Queue"="Transparent"}

            CGPROGRAM

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            // pbr光照需要
            #include "UnityPBSLighting.cginc"
            #include "AutoLight.cginc"

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog


            struct appdata{
                // 顶点坐标，采样坐标，发现，切线
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 texcoord1 : TEXCOORD1;
                float4 tangent : TANGENT;
            };

            struct v2f{
                // 裁剪坐标，采样坐标，法线，副切线，世界坐标，切线空间转世界空间的矩阵
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float3 bitangent :TEXCOORD2;
                float3 worldPos : TEXCOORD3;
                // 变换矩阵
                float4 TtoW0 : TEXCOORD4;
                float4 TtoW1 : TEXCOORD5;
                float4 TtoW2 : TEXCOORD6;

                // 光照贴图阴影坐标
                UNITY_SHADOW_COORDS(7)
                UNITY_FOG_COORDS(8)
            };

            struct SurfaceOutputHair{
                // 会使用的头发性质，反射率，法线，粗糙度，光照吸收模拟环境光遮蔽，透明度，离心率，金属度，高光偏移量
                half3 Albedo;
                half3 Normal;
                half Roughness;
                half AO;
                half Alpha;
                half3 Emission;
                half Metallic;
                half Shift;
                float2 UV;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _AlphaTex;
            float4 _AlphaTex_ST;
            sampler2D _AoTex;
            sampler2D _RoughnessTex;
            sampler2D _EmissionTex;
            sampler2D _MetallicTex;
            sampler2D _NormalMap;
            sampler2D _PrimaryShiftTex;
            float4 _PrimaryShiftTex_ST;
            sampler2D _SecondShiftTex;
            float4 _SecondShiftTex_ST;

            float4 _DiffuseColor;
            fixed _Shift;
            float4 _SpecularColor_1;
            float4 _SpecularColor_2;
            fixed _SpecularWidth;
            fixed _SpecularScale;
            fixed _PrimaryShift;
            fixed _SecondShift;
            fixed _Specularity_1;
            fixed _Specularity_2;
            fixed _BumpScale;

            // π和π^0.5，主要是加速计算
            #define PI 3.1415926
            #define SQRT2PI 2.50663

            v2f vert(appdata v){
                v2f o;
                UNITY_INITIALIZE_OUTPUT(v2f, o);//初始化归零
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv,_AlphaTex);
                float3 worldPos=mul(unity_ObjectToWorld, v.vertex).xyz;
                float3 worldNormal=UnityObjectToWorldNormal(v.normal);
                float3 worldTangent=UnityWorldToObjectDir(v.tangent).xyz;
                float3 worldBitangent=cross(worldTangent,worldNormal)*v.tangent.w;
                o.worldPos = worldPos;
                o.normal=UnityObjectToWorldNormal(v.normal);
                o.bitangent =cross(v.normal,v.tangent.xyz)*v.tangent.w*unity_WorldTransformParams.w;
                o.TtoW0 = float4(worldTangent.x,worldBitangent.x,worldNormal.x,worldPos.x);
                o.TtoW1 = float4(worldTangent.y,worldBitangent.y,worldNormal.y,worldPos.y);
                o.TtoW2 = float4(worldTangent.z,worldBitangent.z,worldNormal.z,worldPos.z);
                // 光照贴图纹理坐标
                UNITY_TRANSFER_LIGHTING(o,v.texcoord1.xy);
                return o;
            }

            // 采样法线贴图获取法线
            float3 getNormal(float4 TtoW0,float4 TtoW1,float4 TtoW2,float2 uv){
                // 采样发现，这里注意必须是设置为NromalMap
                float4 packedNormal = tex2D(_NormalMap,uv);
                //图片没有设置成normal map
                //float33 tangentNormal;
                //tangentNormal.xy = (packedNormal.xy * 2 - 1)*_BumpScale;
                //tangentNormal.z = sqrt(1 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));
                // 解码得到采样后的切线坐标系下的法线
                float3 tangentNormal=UnpackNormal(packedNormal);
                tangentNormal.xy*=_BumpScale;
                // 需要转换为世界坐标系下的法线
                float3 worldNormal = normalize(float3(dot(TtoW0.xyz,tangentNormal),dot(TtoW1.xyz,tangentNormal),dot(TtoW2.xyz,tangentNormal)));
                return worldNormal;

            }

            inline float square(float x){
                // 不用pow加速计算
                return x*x;
            }

            // M项使用的高斯分布计算式
            float Hair_g(float B,float Theta){
                return exp(-0.5 * square(Theta) / (B * B)) / (SQRT2PI * B);
            }

            // 菲涅尔项
            inline float3 SpecularFresnel(float F0, float x) {
                return F0 + (1.0f - F0) * pow(1 - x, 5);
            }

            // 核心公式，计算BSDF，这里采用UE类似的模拟加速计算，参考文章：
            // [Marschner et al. 2003, "Light Scattering from Human Hair Fibers"]
            // [Pekelis et al. 2015, "A Data-Driven Light Scattering Model for Hair"]
            float3 HairSpecularMarschner(SurfaceOutputHair sh,float3 N,float3 V,float3 L,float Shadow,float Backlit,float Area){
                float3 S = 0;
                const float dotVL = dot(V,L);
                const float SinThetaL = clamp(dot(N,L),-1.f,1.f);
                const float SinThetaV = clamp(dot(N,V),-1.f,1.f);
                float CosThetaL = sqrt(max(0,1-SinThetaL*SinThetaL));
                float CosThetaV = sqrt(max(0,1-SinThetaV*SinThetaV));
                float CosThetaD = sqrt((1 + CosThetaL * CosThetaV + SinThetaL * SinThetaV) / 2.0);

                const float3 Lp = L-SinThetaL*N;
                const float3 Vp = V-SinThetaV*N;
                const float CosPhi = dot(Lp,Vp)*rsqrt(dot(Lp,Lp)*dot(Vp,Vp) + 1e-4);
                const float CosHalfPhi = sqrt(saturate(0.5+0.5*CosPhi));

                /**
                * η'的拟合
                * 原型：η' = sqrt( η * η - 1 + CosThetaD^2) / CosThetaD;
                * float n_prime = sqrt( n*n - 1 + Pow2( CosThetaD ) ) / CosThetaD;
                * 拟合思路：η即人类发丝折射率写死为1.55, 拟合后的η'如下：
                * η' = 1.19 / CosThetaD + 0.36 * CosThetaD;
                */
                float n=1.55;
                float n_prime = 1.19/CosThetaD+0.36*CosThetaD;

                float Shift=sh.Shift;
                float Alpha[] = {
                    -Shift*2,
                    Shift,
                    Shift*4
                };

                float B[]={
                    Area+square(sh.Roughness),
                    Area+square(sh.Roughness)/2,
                    Area+square(sh.Roughness)*2
                };

                float F0=square((1-n)/(1+n));

                float3 Tp;
                float Mp,Np,A,f,Fp,h,a;

                // R
                // N_R\left(\theta_i, \theta_r, \phi\right)=\left(\frac{1}{4} \Cos \frac{\phi}{2}\right) A(0, h)
                Mp=Hair_g(B[0],SinThetaL+SinThetaV-Alpha[0]);
                A=SpecularFresnel(F0,sqrt(saturate(0.5 + 0.5 * dotVL)));
                Np=0.25*CosHalfPhi*A;
                S+=Mp*Np*lerp(1,Backlit,saturate(-dotVL));
                // S+=Mp;

                // TT
                /**
                * Step1: 对h的拟合
                * h的原型计算公式如下：
                * float h = CosHalfPhi * rsqrt( 1 + a*a - 2*a * sqrt( 0.5 - 0.5 * CosPhi ) );
                * float h = CosHalfPhi * ( ( 1 - Pow2( CosHalfPhi ) ) * a + 1 );
                *
                * 最终曲线拟合完的h_tt如下：
                */
                Mp=Hair_g(B[1],SinThetaL+SinThetaV-Alpha[1]);
                a=1/n_prime;
                h=CosHalfPhi*(1+a*(0.6 - 0.8 * CosPhi));
                
                /**
                * Step2：η'的拟合
                * 原型：η' = sqrt( η * η - 1 + CosThetaD^2) / CosThetaD;
                * 拟合思路：η即人类发丝折射率写死为1.55, 拟合后的η'如下：
                * η' = 1.19 / CosThetaD + 0.36 * CosThetaD;
                * 代码往上翻
                */
                f=SpecularFresnel(F0,CosThetaD*sqrt(saturate(1 - h*h)));
                Fp=square(1 - f);

                /**
                * Step3：对于吸收项T的拟合：选择Pixar的方案但没有直接用，还是做了拟合
                *
                * T与γ_t的计算原型如下：
                * T(θ，φ) = e^{-2 * μ_a * (1 + Cos(2γ_t)) / (Cosθt)}，其中γt = sin^-1(h / η')
                * 代码实现：float yi = asinFast(h); float yt = asinFast(h / n_prime);
                * 
                * 参考Pixar的实现：
                * T(θ，φ) = e^{-epsilo(C) * Cosγt / Cosθd}
                * 代码实现：float3 Tp = pow( GBuffer.BaseColor, 0.5 * ( 1 + Cos(2*yt) ) / CosThetaD );
                */
                // 这里C直接使用折射率进一步简化
                Tp = pow(sh.Albedo, 0.5 * sqrt(1 - square((h * a))) / CosThetaD);
                /**
                * Step4: 对分布项D的拟合
                * 技术原型：Pixar's Logistic Distribution Function
                * D(φ，s, μ) = (e^{(φ - μ) / s}) / (s^{1 + e^{(φ - μ) / s}}^2)
                * 
                * 考虑s_tt实际上贡献很小，因此近似如下：
                * D_TT(φ) = D(φ，0.35，Π) ≈ e^{-3.65Cosφ - 3.98}
                */
                Np=exp(-3.65*CosPhi-3.98);
                S+=Mp*Np*Fp*Tp*Backlit;
                // S+=Mp;

                // TRT
                /**
                * Step1 ：对h的拟合
                * h_trt = sqrt(3) / 2
                * float h = 0.75;
                */
                Mp=Hair_g(B[2],SinThetaL+SinThetaV-Alpha[2]);
                f=SpecularFresnel(F0,CosThetaD*0.5f);
                Fp=square(1 - f)*f;
                
                /**
                * Step2：对于吸收项T的拟合
                * T_TRT(θ，φ) = C^{0.8 / Cosθd}
                */
                Tp=pow(sh.Albedo,0.8/CosThetaD);
                Np=exp(17*CosPhi-16.78);
                S+=Mp*Np*Fp*Tp;
                // S+=Mp;
                
                return S;
            }

            // Kajiya推导的解析解，主要是模拟头发间的散射
            float3 HairDiffuseKajiya(SurfaceOutputHair sh,float3 N,float3 V,float3 L,float Shadow,float Backlit,float Area){
                float3 S = 0;
                float KajiyaDiffuse = 1-abs(dot(N,L));

                float3 FakeNormal = normalize(V-N*dot(V,N));
                N=FakeNormal;

                // Hack approximation for multiple scattering.
                float Wrap=1;
                float dotNL=saturate((dot(N,L)+Wrap)/square(1+Wrap));
                float DiffuseScatter=( (1 / PI) * lerp(dotNL, KajiyaDiffuse, 0.33))*sh.Metallic;
                float Luma=Luminance(sh.Albedo);
                float3 ScatterTint=pow(sh.Albedo/Luma,1 - Shadow);
                S=sqrt(sh.Albedo)*DiffuseScatter*ScatterTint;

                return S;
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

            float3 HairShading(SurfaceOutputHair sh,float3 N,float3 V,float3 L,float Shadow,float Backlit,float Area){
                float3 S= float3(0,0,0);
                // add Specualr
                S=HairSpecularMarschner(sh,N,V,L,Shadow,Backlit,Area);
                // add Diffuse
                S+=HairDiffuseKajiya(sh,N,V,L,Shadow,Backlit,Area);
                // 校验一下，保证S不会小于零
                S=-min(-S,0.0);
                return S;
            }

            float3 HairBxDF(SurfaceOutputHair sh,float3 N,float3 V,float3 L,float Shadow,float Backlit,float Area){
                // 这里sh提供表面材质属性，Shadow提供头发之间的阴影遮蔽强度，Backlit影响透光强度，Area决定散射强度
                return HairShading(sh,N,V,L,Shadow,Backlit,Area);
            }

            inline void  LightingHair_GI(SurfaceOutputHair sh,UnityGIInput giInput,inout UnityGI gi){
                // 计算全局光照效果，会更新gi中的light和diffuse参数，参考了giInput,法线和环境光遮蔽生成
                gi=UnityGlobalIllumination(giInput,sh.AO,sh.Normal);
            }

            inline fixed4 LightingHair(SurfaceOutputHair sh,float3 viewDir,float3 Bitangent,UnityGI gi){
                fixed4 c=(0,0,0,sh.Alpha);
                // if(sh.Alpha<0.9){
                    //     c = fixed4(0,0,0,0);
                    //     }else{
                    //     c =fixed4(0,0,0,sh.Alpha);
                // }
                // 直接光照，由于光照直射强度高，所以是提供透射的主要因素，但是散射能力弱
                c.rgb=gi.light.color*HairBxDF(sh,sh.Normal,viewDir,gi.light.dir,0.4f,1.0f,0.0f);
                // 间接光照，基本不提供透射，但是简介光照主要提供表面散射，是头发暗部底色的主要贡献
                float3 reflect=normalize(viewDir-sh.Normal*dot(sh.Normal,viewDir));
                // 此时贡献光源不是来自灯光，而是根据视线反射对应的反射处，别忘了乘直径
                c.rgb+=gi.indirect.diffuse*6.28f*HairBxDF(sh,sh.Normal,viewDir,reflect,0.1f,0.0f,0.5f);
                float3 spec=HairSpecular(Bitangent,sh.Normal,gi.light.dir,viewDir,sh.UV);
                c.rgb+=gi.light.color*spec;

                return c;
            }

            fixed4 frag(v2f i) : SV_TARGET{
                float3 l=normalize(UnityWorldSpaceLightDir(i.worldPos));
                float3 v=normalize(UnityWorldSpaceViewDir(i.worldPos));
                // float3 n=getNormal(i.TtoW0,i.TtoW1,i.TtoW2,i.uv);
                float3 n = normalize(i.normal);

                float3 albedo = tex2D(_MainTex,i.uv);
                float ao =tex2D(_AoTex,i.uv);
                float alpha=tex2D(_AlphaTex,i.uv).r;
                float roughness=tex2D(_RoughnessTex,i.uv);
                float metallic=tex2D(_MetallicTex,i.uv).a;
                float3 emission=tex2D(_EmissionTex,i.uv);

                SurfaceOutputHair sh;
                UNITY_INITIALIZE_OUTPUT(SurfaceOutputHair, sh);//初始化归零
                sh.Normal=n;
                sh.AO=ao;
                sh.Albedo = fixed4(albedo*_DiffuseColor,alpha); 
                sh.Roughness=roughness;
                sh.Emission=emission;
                sh.Alpha=alpha;
                sh.Metallic=metallic;
                sh.Shift=_Shift;
                sh.UV=i.uv;

                // compute lighting & shadowing factor
                //计算光照衰减和阴影
                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos)

                // 计算全局光照
                UnityGI gi;
                UNITY_INITIALIZE_OUTPUT(UnityGI, gi);//初始化归零
                gi.indirect.diffuse=0;
                gi.indirect.specular=0;
                gi.light.color = _LightColor0.rgb;
                gi.light.dir=l;

                UnityGIInput giInput;
                UNITY_INITIALIZE_OUTPUT(UnityGIInput, giInput);//初始化归零
                giInput.light=gi.light;
                giInput.worldPos=i.worldPos;
                giInput.worldViewDir=v;
                giInput.atten=atten;
                giInput.probeHDR[0]=unity_SpecCube0_HDR;
                giInput.probeHDR[1]=unity_SpecCube1_HDR;

                // 计算全局光照
                LightingHair_GI(sh,giInput,gi);
                // 计算最终颜色值
                fixed4 col = LightingHair(sh,v,i.bitangent,gi);
                // fixed4 col = fixed4(gi.light.color,1.0);
                // fixed4 col=fixed4(n.r,n.g,n.b,1.0);
                // fixed4 col=fixed4(sh.Alpha,sh.Alpha,sh.Alpha,sh.Alpha);
                clip(col.a-0.2f);
                return col;
            }   
            ENDCG
        }
        
        
        
    }

    FallBack "Diffuse"
}
