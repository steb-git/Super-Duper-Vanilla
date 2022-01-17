#include "/lib/utility/util.glsl"
#include "/lib/structs.glsl"
#include "/lib/settings.glsl"

INOUT vec2 texCoord;

INOUT vec3 norm;

#ifdef VERTEX
    uniform mat4 gbufferModelView;
    uniform mat4 gbufferModelViewInverse;

    #if defined DOUBLE_VANILLA_CLOUDS
        uniform int instanceId;

        const int countInstances = 2;
    #endif
    
    void main(){
        // Feet player pos
        vec4 vertexPos = gbufferModelViewInverse * (gl_ModelViewMatrix * gl_Vertex);

        vec2 coord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        #ifdef DOUBLE_VANILLA_CLOUDS
            texCoord = instanceId == 1 ? coord : -coord;
            if(instanceId > 0) vertexPos.y += SECOND_CLOUD_HEIGHT * instanceId;
        #else
            texCoord = coord;
        #endif

	    norm = normalize(mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal));
        
	    gl_Position = gl_ProjectionMatrix * (gbufferModelView * vertexPos);
    }
#endif

#ifdef FRAGMENT
    uniform sampler2D texture;
    
    // View matrix uniforms
    uniform mat4 gbufferModelViewInverse;

    // Projection matrix uniforms
    uniform mat4 gbufferProjectionInverse;

    // Shadow view matrix uniforms
    uniform mat4 shadowModelView;

    // Shadow projection matrix uniforms
    uniform mat4 shadowProjection;

    /* Position uniforms */
    uniform vec3 cameraPosition;

    uniform vec3 shadowLightPosition;

    /* Screen resolutions */
    uniform float viewWidth;
    uniform float viewHeight;

    #if defined CLOUD_FADE || defined TEMPORAL_ACCUMULATION
        // Get frame time
        uniform float frameTimeCounter;
    #endif

    // Get world time
    uniform float day;
    uniform float dawnDusk;
    uniform float twilight;

    uniform int isEyeInWater;

    uniform float nightVision;
    uniform float rainStrength;

    uniform ivec2 eyeBrightnessSmooth;

    uniform vec3 fogColor;

    #include "/lib/universalVars.glsl"

    #include "/lib/lighting/shdDistort.glsl"
    #include "/lib/utility/spaceConvert.glsl"
    #include "/lib/utility/texFunctions.glsl"
    #include "/lib/utility/noiseFunctions.glsl"

    #include "/lib/lighting/shdMapping.glsl"
    #include "/lib/lighting/GGX.glsl"

    #include "/lib/lighting/complexShadingForward.glsl"

    void main(){
        // Declare and get positions
        positionVectors posVector;
        posVector.screenPos = vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z);
	    posVector.viewPos = toView(posVector.screenPos);
        posVector.eyePlayerPos = mat3(gbufferModelViewInverse) * posVector.viewPos;
        posVector.feetPlayerPos = posVector.eyePlayerPos + gbufferModelViewInverse[3].xyz;

        #ifdef END
			posVector.lightPos = shadowLightPosition;
		#else
			posVector.lightPos = mat3(gbufferModelViewInverse) * shadowLightPosition + gbufferModelViewInverse[3].xyz;
		#endif
	
		#ifdef SHD_ENABLE
			posVector.shdPos = mat3(shadowProjection) * (mat3(shadowModelView) * posVector.feetPlayerPos + shadowModelView[3].xyz) + shadowProjection[3].xyz;
		#endif

	    // Declare materials
	    matPBR material;

        float albedoAlpha = texture2D(texture, texCoord).a;
        // Assign normals
        material.normal = norm;

        #ifdef CLOUD_FADE
            float fade = smootherstep(sin(frameTimeCounter * FADE_SPEED) * 0.5 + 0.5);
            float albedoAlpha2 = texture2D(texture, 0.5 - texCoord).a;
            albedoAlpha = mix(albedoAlpha, albedoAlpha2, fade * (1.0 - rainStrength) + albedoAlpha2 * rainStrength);
        #endif

        #if WHITE_MODE == 2
            material.albedo = vec4(0, 0, 0, albedoAlpha);
        #else
            material.albedo = vec4(albedoAlpha);
        #endif

        vec4 sceneCol = vec4(0);

        if(material.albedo.a > 0.00001){
            material.metallic = 0.04;
            material.ss = 0.5;
            material.emissive = 0.0;
            material.smoothness = 0.0;

            // Apply vanilla AO
            material.ambient = 1.0;
            material.light = vec2(0, 1);

            #ifdef TEMPORAL_ACCUMULATION
                sceneCol = complexShadingGbuffers(material, posVector, toRandPerFrame(getRand1(posVector.screenPos.xy, 8), frameTimeCounter));
            #else
                sceneCol = complexShadingGbuffers(material, posVector, getRand1(posVector.screenPos.xy, 8));
            #endif
        } else discard;

    /* DRAWBUFFERS:012 */
        gl_FragData[0] = sceneCol; //gcolor
        gl_FragData[1] = vec4(material.normal * 0.5 + 0.5, 1); //colortex1
        gl_FragData[2] = vec4(material.albedo.rgb, 1); //colortex2
    }
#endif