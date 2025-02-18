/// ------------------------------------- /// Vertex Shader /// ------------------------------------- ///

#ifdef VERTEX
    out vec2 texCoord;

    out vec4 vertexColor;

    #if ANTI_ALIASING == 2
        /* Screen resolutions */
        uniform float viewWidth;
        uniform float viewHeight;

        #include "/lib/utility/taaJitter.glsl"
    #endif

    void main(){
        texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        gl_Position = ftransform();

        #if ANTI_ALIASING == 2
            gl_Position.xy += jitterPos(gl_Position.w);
        #endif

        vertexColor = gl_Color;
    }
#endif

/// ------------------------------------- /// Fragment Shader /// ------------------------------------- ///

#ifdef FRAGMENT
    in vec2 texCoord;

    in vec4 vertexColor;

    // Get albedo texture
    uniform sampler2D texture;

    uniform int renderStage;

    #if WORLD_SUN_MOON == 1 && SUN_MOON_TYPE == 2 && defined WORLD_LIGHT
        #include "/lib/universalVars.glsl"
    #endif
    
    void main(){
        vec4 albedo = texture2D(texture, texCoord);

        // Alpha test, discard immediately
        if(albedo.a <= ALPHA_THRESHOLD) discard;

    /* DRAWBUFFERS:0 */
        // Detect and calculate the sun and moon
        if(renderStage == MC_RENDER_STAGE_SUN || renderStage == MC_RENDER_STAGE_MOON)
            #if WORLD_SUN_MOON == 1 && SUN_MOON_TYPE == 2 && defined WORLD_LIGHT
                gl_FragData[0] = vec4(toLinear(albedo.rgb * vertexColor.rgb) * albedo.a * vertexColor.a * SUN_MOON_INTENSITY * SUN_MOON_INTENSITY * LIGHT_COL_DATA_BLOCK, 1);
            #else
                discard;
            #endif
        // Otherwise, calculate skybox
        else gl_FragData[0] = vec4(toLinear(albedo.rgb * vertexColor.rgb) * albedo.a * vertexColor.a * SKYBOX_BRIGHTNESS, 1);
    }
#endif