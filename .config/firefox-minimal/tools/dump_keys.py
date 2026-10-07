import sys, os, time
sys.path.insert(0, os.path.expanduser("~/dotfiles/.config/firefox-minimal/tools"))
from marionette import Marionette, build_profile, launch
JS = r"""
const out = [];
const mod = k => {
  const m = (k.getAttribute('modifiers')||'').replace('accel','Cmd')
    .replace('shift','Shift').replace('alt','Opt').replace('control','Ctrl')
    .split(/[,\s]+/).filter(Boolean).join('+');
  const key = k.getAttribute('key') || k.getAttribute('keycode')||'';
  const pretty = key.replace('VK_','');
  return (m ? m+'+' : '') + pretty;
};
document.querySelectorAll('key').forEach(k => {
  const id = k.id || '';
  const cmd = k.getAttribute('command') || k.getAttribute('oncommand') || '';
  if (!k.getAttribute('key') && !k.getAttribute('keycode')) return;
  out.push([mod(k), id, cmd.slice(0,46)].join('\t'));
});
return out.sort().join('\n');
"""
proc = launch(build_profile(), 1200, 800)
try:
    m = Marionette(); m.new_session(); m.chrome(); time.sleep(2)
    print(m.script(JS))
    m.quit()
finally:
    time.sleep(1)
    if proc.poll() is None: proc.terminate()
