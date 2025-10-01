# Roadmap

## Completed Milestones
- Swapped the Sailfish touch overlay mock-up for a GLES2 shader/VBO renderer that ships on device builds.
- Hardened the SDL bootstrap by aborting on initialisation failures, loading controller mappings from the Sailfish data install, and fixing hot-plug logic to use proper instance identifiers.
- Bundled the default controller mapping database with the `res/` assets so un-packaged desktop builds keep their SDL mappings in sync with Sailfish releases.
- Authored step-by-step walkthroughs for `build_armhf.sh` and `build_rpm.sh`, making the release pipeline reproducible for new maintainers.
- Hardened the Sailfish RPM packaging helper to enumerate every default `.default` target, quote command arguments, and fail loudly when the SDK lacks configured targets.

## Near-Term Priorities
1. Validate the refreshed GLES2 overlay on Sailfish OS hardware to confirm input hit boxes and rendering alignment.
2. Package the required GLESv2/EGL/SDL2 development libraries alongside the cross-compilation toolchains to simplify local builds.
 
## Longer-Term Goals
- Continue optimising the GLES2 rendering path (buffer reuse, shader tuning, frame pacing) for mobile performance.
- Integrate a touch keyboard and optional aim-assist controls into the overlay experience.
- Automate cross-builds and smoke tests through CI once the manual pipeline is stable.
