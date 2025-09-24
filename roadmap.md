# Roadmap

## Completed Milestones
- Swapped the Sailfish touch overlay mock-up for a GLES2 shader/VBO renderer that ships on device builds.

## Near-Term Priorities
1. Validate the refreshed GLES2 overlay on Sailfish OS hardware to confirm input hit boxes and rendering alignment.
2. Document repeatable build procedures for `build_rpm.sh` and `build_armhf.sh` so maintainers can reproduce releases.
3. Package the required GLESv2/EGL/SDL2 development libraries alongside the cross-compilation toolchains to simplify local builds.

## Longer-Term Goals
- Continue optimising the GLES2 rendering path (buffer reuse, shader tuning, frame pacing) for mobile performance.
- Integrate a touch keyboard and optional aim-assist controls into the overlay experience.
- Automate cross-builds and smoke tests through CI once the manual pipeline is stable.
