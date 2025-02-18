uniform float isPrecipitationRain;
uniform float wetness;

// For Optifine to detect this option
#ifdef ENVIRO_PBR
#endif

// Environment PBR calculation
void enviroPBR(inout structPBR material){
    float rainMatFact = TBN[2].y * max(0.0, (lmCoord.y - 0.8) * 5.0) * (1.0 - material.porosity) * isPrecipitationRain * wetness;

    if(rainMatFact > 0.005){
        vec2 noiseData = texture2DLod(noisetex, worldPos.xz * 0.001953125, 0).xy;
        rainMatFact *= saturate(noiseData.y + noiseData.x - 0.25);

        material.normal = mix(material.normal, TBN[2], rainMatFact);
        material.metallic = max(0.04 * rainMatFact, material.metallic);
        material.smoothness = mix(material.smoothness, 0.96, rainMatFact);
        material.albedo.rgb *= 1.0 + rainMatFact * 0.5;
    }
}