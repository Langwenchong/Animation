
Shader "Custom/Eye Shading" {
    Properties{
        //Cornea角膜
        //Iris虹膜
        //Sclera巩膜
        // Pupil 瞳孔
        // Lens 晶状体，眼球突出部分
        _Color("Iris Colro",Color)=(1,1,1,1)
        _MainTex("Main Texture",2D)="white" {}
        _AOTex("AO Texture",2D)="white" {}
        _EmissiveTex("Emissive Texture",2D)="white" {}
        _BaseIrisSize("Iris Radius in texture",Float)=0.4
        _BasePupilSize("Pupil Radius in texture",Float)=0.1
        _BaseNormalMap("Base Normal Map",2D)="bump" {}
        _BaseNormalScale("Base Normal Scale",Float)=1.0
        _LensNormalMap("Lens Normal Map",2D)="bump"{}
        _LensNormalScale("Lens Normal Scale",Float)=1.0
        _ScleraNormalMap("Sclera Vessel",2D)="bump"{}
        _ScleraNormalScale("Sclera Vessel Normal Scale",Float)=1.0
        _Mask("Mask(R=Parallax,G=Iris)",2D)="black" {}
        _BaseSmoothness("Base Smoothness",Range(0,1))=0.4
        _LensSmoothness("Lens Smoothness",Range(0,1))=0.9
        _Parallax("Lens Parallax",Float)=0.1
        _IrisScale("Iris Scale",Float)=1.0
        _PupilScale("Pupil Scale",Range(0,1))=0.3
    }
    SubShader{

        Tags{"RenderType"="Opaque"}
        LOD 200
        
        // Base Pass
        CGPROGRAM
        // 使用表面着色器自动计算标准光照
        #pragma surface surf Standard fullforwardshadows nolightmap
        // 视差贴图
        #pragma shader_feature PRALLAX
        
        struct Input{
            float2 uv_MainTex;
            float3 viewDir;
        };

        sampler2D _MainTex;
        sampler2D _AOTex;
        sampler2D _EmissiveTex;
        sampler2D _BaseNormalMap;
        sampler _Mask;

        fixed4 _Color;
        fixed _BaseIrisSize;
        fixed _BasePupilSize;
        fixed _BaseNormalScale;
        fixed _LensNormalScale;
        fixed _BaseSmoothness;
        fixed _LensSmoothness;
        fixed _IrisScale;
        fixed _PupilScale;
        fixed _Parallax;

        #define PARALLAX_BIAS 0
        #define RAYMARCH_STEPS 8

        float getParallaxHeight(float2 uv){
            return tex2D(_Mask,uv).r*(-_Parallax);
        }

        float2 ParallaxRaymarching(float2 uv,float2 viewDir){
            float stepSize=1.1/RAYMARCH_STEPS;
            // 采样偏移总量
            float2 uvOffset=0;
            // 每次的偏移步长
            float2 uvDelta=-viewDir*(stepSize*_Parallax);
            float stepHeight=-0.001;
            // 获取这个位置处的高度判断是否有视差
            float surfaceHeight=getParallaxHeight(uv);
            float2 prevUVoffset=uvOffset;
            float prevStepHeight=0;
            float prevSurfaceHeight=surfaceHeight;
            // 模拟raymarching算法，每次走一个步长，如果走规定步数之后或者当前位置与贴图表面很近已经相交则停止找到了偏移后的采样点
            [unroll]for(int i=1;i<RAYMARCH_STEPS && stepHeight>surfaceHeight;i++){
                // 记录本次值
                prevUVoffset = uvOffset;
                prevStepHeight=stepHeight;
                prevSurfaceHeight=surfaceHeight;

                // 更新记录总偏移量
                uvOffset-=uvDelta;
                // 更新记录总高度
                stepHeight-=stepSize;
                // 查看此时位置的偏移高度
                surfaceHeight=getParallaxHeight(uv+uvOffset);
            }
            float prevDifference=prevStepHeight-prevSurfaceHeight;
            float difference=surfaceHeight-stepHeight;
            float t =prevDifference/(prevDifference+difference);
            uvOffset=lerp(prevUVoffset,uvOffset,t);
            return uvOffset;
        }

        // 放缩扩张
        float remap(float value,float a,float b,float a2,float b2){
            return a2+(value-a)*(b2-a2)/(b-a);
        }

        void surf(Input IN,inout SurfaceOutputStandard o){
            float2 uv=IN.uv_MainTex;
            float4 mask=tex2D(_Mask,uv);

            // iris scale
            uv-=0.5;
            uv/=_IrisScale;
            uv+=0.5;

            // iris parallax 
            IN.viewDir.xy/=(-IN.viewDir.z+0.1);
            uv+=ParallaxRaymarching(uv,IN.viewDir);

            // pupil dilation
            uv-=0.5;
            float r=length(uv)*2;
            float R=r;
            float pr=_BaseIrisSize*_PupilScale;
            if(r<pr){
                R=remap(r,0,R,0,_BasePupilSize);
                }else if(r<_BaseIrisSize){
                R=remap(r,pr,_BaseIrisSize,_BasePupilSize,_BaseIrisSize);
            }
            uv=uv/r*R;
            uv+=0.5;

            float3 normal=UnpackNormal(tex2D(_BaseNormalMap,uv));
            normal.xy*=_BaseNormalScale;

            mask=tex2D(_Mask,uv);
            // 改变颜色
            fixed4 c=tex2D(_MainTex,uv)*lerp(1,_Color,mask.g);
            o.Albedo=c.rgb;
            o.Normal=normal;
            o.Emission=tex2D(_EmissiveTex,uv);
            o.Occlusion=tex2D(_AOTex,uv).r;
            o.Metallic=0;
            o.Smoothness=_BaseSmoothness;
            o.Alpha=1;
        }
        ENDCG

        
        // Lens Pass
        Blend One One
        ZWrite Off

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows nolightmap
        struct Input{
            float2 uv_MainTex;
        };

        sampler2D _LensNormalMap;
        sampler2D _Mask;
        
        fixed _LensSmoothness;
        fixed _IrisScale;
        fixed _LensNormalScale;

        void surf(Input IN,inout SurfaceOutputStandard o){
            float2 uv=IN.uv_MainTex;
            float3 mask=tex2D(_Mask,uv);

            // iris scale
            uv-=0.5;
            uv/=_IrisScale;
            uv+=0.5;

            float3 normal=UnpackNormal(tex2D(_LensNormalMap,uv));
            normal.xy*=_LensNormalScale;

            o.Albedo=0;
            o.Normal=normal;
            o.Metallic=0;
            o.Smoothness=_LensSmoothness;
            o.Alpha=1;
        }
        ENDCG

        // Sclera Vessel pass
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows nolightmap
        struct Input{
            float2 uv_MainTex;
        };

        sampler2D _ScleraNormalMap;

        fixed _ScleraNormalScale;

        void surf(Input IN,inout SurfaceOutputStandard o){
            float2 uv=IN.uv_MainTex;
            float3 normal=UnpackNormal(tex2D(_ScleraNormalMap,uv));
            normal.xy*=_ScleraNormalScale;

            o.Albedo=0;
            o.Normal=normal;
            o.Metallic=0;
            o.Alpha=1;
            o.Smoothness=0.5;
        }
        ENDCG
    }
    Fallback "Diffuse"

}
