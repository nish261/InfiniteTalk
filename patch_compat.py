import glob, re

patches = 0

for f in glob.glob('/InfiniteTalk/**/*.py', recursive=True):
    src = open(f).read()
    changed = False

    # Fix 1: flash_attn ImportError (ABI mismatch catch)
    if 'except ModuleNotFoundError' in src and 'flash_attn' in src:
        src = src.replace('except ModuleNotFoundError:', 'except Exception:')
        changed = True

    # Fix 2: inspect.ArgSpec removed in Python 3.11
    if 'from inspect import ArgSpec' in src:
        src = src.replace(
            'from inspect import ArgSpec',
            'try:\n    from inspect import ArgSpec\nexcept ImportError:\n    from inspect import FullArgSpec as ArgSpec'
        )
        changed = True

    if changed:
        open(f, 'w').write(src)
        print('Patched:', f)
        patches += 1

print(f'Done — {patches} file(s) patched')
