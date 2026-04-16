import glob

for f in glob.glob('/InfiniteTalk/**/*.py', recursive=True):
    src = open(f).read()
    if 'except ModuleNotFoundError' in src and 'flash_attn' in src:
        patched = src.replace('except ModuleNotFoundError:', 'except Exception:')
        open(f, 'w').write(patched)
        print('Patched:', f)
print('Done')
