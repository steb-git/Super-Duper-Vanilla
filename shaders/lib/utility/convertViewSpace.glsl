vec3 toView(vec3 pos){
    vec3 viewPos = vec3(vec2(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y) * (pos.xy * 2.0 - 1.0) + gbufferProjectionInverse[3].xy, gbufferProjectionInverse[3].z);
    return viewPos / (gbufferProjectionInverse[2].w * (pos.z * 2.0 - 1.0) + gbufferProjectionInverse[3].w);
}

float toView(float depth){
	return gbufferProjectionInverse[3].z / (gbufferProjectionInverse[2].w * (depth * 2.0 - 1.0) + gbufferProjectionInverse[3].w);
}