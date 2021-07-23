#include "/lib/utility/util.glsl"
#include "/lib/structs.glsl"
#include "/lib/settings.glsl"

INOUT vec2 texcoord;

#ifdef VERTEX
    void main(){
        gl_Position = ftransform();
        texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    }
#endif

#ifdef FRAGMENT
    #if defined AUTO_EXPOSURE || defined TEMPORAL_ACCUMULATION
        const bool gcolorMipmapEnabled = true;
        const bool colortex6MipmapEnabled = true;
        const bool colortex6Clear = false;
    #endif

    uniform sampler2D gcolor;

    #ifdef BLOOM
        uniform sampler2D colortex2;
    #endif

    uniform sampler2D colortex4;
    
    #include "/lib/globalVars/screenUniforms.glsl"
    #include "/lib/globalVars/timeUniforms.glsl"
    #include "/lib/globalVars/gameUniforms.glsl"

    #ifdef TEMPORAL_ACCUMULATION
        uniform sampler2D depthtex0;

        #include "/lib/globalVars/matUniforms.glsl"
        #include "/lib/globalVars/posUniforms.glsl"
    #endif

    #if defined TEMPORAL_ACCUMULATION || AUTO_EXPOSURE == 2
        uniform sampler2D colortex6;
    #endif

    #if AUTO_EXPOSURE == 1
        #include "/lib/globalVars/universalVars.glsl"
    #endif

    #ifdef TEMPORAL_ACCUMULATION
        #include "/lib/lighting/shdDistort.glsl"
        #include "/lib/utility/spaceConvert.glsl"
    #endif

    #include "/lib/post/spectral.glsl"
    #include "/lib/post/tonemap.glsl"

    #ifdef BLOOM
        vec3 getBloomTile(vec2 uv, vec2 coords, float LOD){
            // Uncompress bloom
            return texture2D(colortex2, uv / exp2(LOD) + coords).rgb;
        }
    #endif

    void main(){
        // Original scene color
        vec3 color = texture2D(gcolor, texcoord).rgb;

        #ifdef BLOOM
            // Uncompress the HDR colors and upscale
            vec3 eBloom = getBloomTile(texcoord, vec2(0), 2.0 * BLOOM_LOD);
            eBloom += getBloomTile(texcoord, vec2(0, 0.26), 3.0 * BLOOM_LOD);
            eBloom += getBloomTile(texcoord, vec2(0.135, 0.26), 4.0 * BLOOM_LOD);
            eBloom += getBloomTile(texcoord, vec2(0.2075, 0.26), 5.0 * BLOOM_LOD);
            eBloom += getBloomTile(texcoord, vec2(0.135, 0.3325), 6.0 * BLOOM_LOD);
            eBloom += getBloomTile(texcoord, vec2(0.160625, 0.3325), 7.0 * BLOOM_LOD);
            eBloom *= 0.167;

            eBloom = (1.0 / (1.0 - eBloom) - 1.0) * BLOOM_BRIGHTNESS;
            color += eBloom;
        #endif

        #ifdef TEMPORAL_ACCUMULATION
            vec2 prevScreenPos = toPrevScreenPos(texcoord);
            float prevMotion = max2(toPrevScreenPos(vec2(1)));
            float velocity = abs(1.0 - prevMotion);
            
            float blendFact = edgeVisibility(prevScreenPos * 0.8 + 0.1) * smoothstep(0.99999, 1.0, 1.0 - velocity);
            float decay = exp2(-ACCUMILATION_SPEED * frameTime);
            blendFact = clamp(blendFact, decay * 0.5, decay);
            
            vec3 prevCol = texture2D(colortex6, texcoord).rgb;
            vec3 accumulated = mix(color, prevCol, blendFact);
            color = accumulated;
        #else
            vec3 accumulated = vec3(0);
        #endif

        #if AUTO_EXPOSURE == 2
            // Get lod
            float lod = int(exp2(min(viewWidth, viewHeight))) - 1.0;
            
            // Get current average scene luminance...
            // Center pixel
            float lumiCurrent = getLuminance(texture2D(gcolor, vec2(0.5), lod).rgb);
            // Left pixel
            lumiCurrent += getLuminance(texture2D(gcolor, vec2(0, 0.5), lod).rgb);
            // Right pixel
            lumiCurrent += getLuminance(texture2D(gcolor, vec2(1, 0.5), lod).rgb);

            // Mix previous and current buffer...
            float accumulatedLumi = mix(lumiCurrent * 0.333, texture2D(colortex6, vec2(0)).a, exp2(-1.0 * frameTime));

            // Apply exposure
            color /= max(accumulatedLumi * AUTO_EXPOSURE_MULT, MIN_EXPOSURE_DENOM);
        #elif AUTO_EXPOSURE == 1
            float accumulatedLumi = 1.0;
            // Recreate our lighting model if it were only shading a single pixel
            #if defined USE_SKY_LIGHTMAP
                // Apply exposure
                color /= max(getLuminance((lightCol * isEyeInWater * (1.0 - eyeBrightFact) * VOL_LIGHT_BRIGHTNESS + (AMBIENT_LIGHTING + nightVision) + nightVision + torchBrightFact * BLOCK_LIGHT_COL + cubed(eyeBrightFact) * (lightCol * rainMult + skyCol)) * 0.36) * AUTO_EXPOSURE_MULT, MIN_EXPOSURE_DENOM);
            #else
                // Apply exposure
                color /= max(getLuminance((lightCol * isEyeInWater * (1.0 - SKY_LIGHT_AMOUNT) * VOL_LIGHT_BRIGHTNESS + (AMBIENT_LIGHTING + nightVision) + nightVision + torchBrightFact * BLOCK_LIGHT_COL + cubed(SKY_LIGHT_AMOUNT) * (lightCol * rainMult + skyCol)) * 0.36) * AUTO_EXPOSURE_MULT, MIN_EXPOSURE_DENOM);
            #endif
        #else
            float accumulatedLumi = 1.0;
            color /= max(accumulatedLumi * AUTO_EXPOSURE_MULT, MIN_EXPOSURE_DENOM);
        #endif

        color *= EXPOSURE;
        // Tonemap and clamp
        color = toneA(whitePreservingLumaBasedReinhardToneMapping(color));

        #ifdef VIGNETTE
            // Apply vignette
            color *= pow(max(1.0 - length(texcoord - 0.5), 0.0), VIGNETTE_INTENSITY);
        #endif

        color = mix(color, vec3(1), getSpectral(colortex4, texcoord, 1.0));

    /* DRAWBUFFERS:0 */
        gl_FragData[0] = vec4(color, 1); //gcolor

        #ifdef BLOOM
        /* DRAWBUFFERS:02 */
            gl_FragData[1] = vec4(eBloom, 1); //colortex2

            #if defined TEMPORAL_ACCUMULATION || AUTO_EXPOSURE == 2
            /* DRAWBUFFERS:026 */
                gl_FragData[2] = vec4(accumulated, max(0.001, accumulatedLumi)); //colortex6
            #endif
        #else
            #if defined TEMPORAL_ACCUMULATION || AUTO_EXPOSURE == 2
            /* DRAWBUFFERS:06 */
                gl_FragData[1] = vec4(accumulated, max(0.001, accumulatedLumi)); //colortex6
            #endif
        #endif
    }
#endif