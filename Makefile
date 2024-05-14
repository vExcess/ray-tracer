build:
	zig build -freference-trace

release:
	zig build -freference-trace --release=fast

run:
	./zig-out/bin/raytracer
