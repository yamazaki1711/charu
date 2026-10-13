#!/bin/zsh
# Живой статус dsh-агента в проекте CHARU.
# Использование: charu-status        (обновляется каждые 3 секунды, Ctrl+C — выход)

WS="--Users-oleg-Documents-charu--"
SESS_DIR="$HOME/.dsh/sessions/$WS"

while true; do
  clear
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║  CHARU · живой статус dsh-агента · $(date '+%H:%M:%S')            ║"
  echo "╚══════════════════════════════════════════════════════════╝"

  NEWEST=$(find "$SESS_DIR" -name "session.v4.jsonl.zstd" -exec stat -f "%m %N" {} \; 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2- | xargs dirname 2>/dev/null | xargs basename 2>/dev/null)
  if [ -z "$NEWEST" ]; then echo "  нет активных сессий"; sleep 3; continue; fi
  TRACE="$SESS_DIR/$NEWEST/session.v4.jsonl.zstd"
  MTIME=$(stat -f "%Sm" -t "%H:%M:%S" "$TRACE" 2>/dev/null)
  AGE=$(( $(date +%s) - $(stat -f %m "$TRACE" 2>/dev/null || date +%s) ))

  echo "  сессия:   $NEWEST (файл обновлён ${AGE}с назад)"
  if [ "$AGE" -gt 300 ]; then
    echo "  ⚠  трейс молчит >5 мин — агент бездействует или ход завершён"
  fi

  zstd -dc "$TRACE" 2>/dev/null | tail -400 > /tmp/_cs.jsonl
  python3 - <<'PYEOF'
import json, datetime, os
def t(ms):
    try: return datetime.datetime.fromtimestamp(ms/1000).strftime('%H:%M:%S')
    except: return '?'
try:
    events=[json.loads(l) for l in open('/tmp/_cs.jsonl')]
except Exception:
    raise SystemExit
turns=[d for d in events if d['type']=='turn/start']
steps=[d for d in events if d['type']=='step/end']
todos=[d for d in events if d['type']=='tool/call' and d.get('data',{}).get('name')=='todo_write']
print(f"  ходов: {len(turns)} | шагов в текущем: {len(steps)}")

# текущее действие: последний tool/call без result или последний шаг
last_call=None; done_ids=set()
for d in events:
    if d['type']=='tool/call': last_call=(d, d['data'].get('name'), d['data'].get('arguments',''))
    if d['type']=='tool/result': done_ids.add(d.get('data',{}).get('callId') or d.get('data',{}).get('message',{}).get('source',{}).get('callId'))
if last_call:
    d,name,args=last_call
    try:
        a=json.loads(args); arg=a.get('command') or a.get('file_path') or a.get('job_id') or str(a)
    except Exception: arg=str(args)
    status='ЖДЁТ РЕЗУЛЬТАТА' if d.get('data',{}).get('callId') not in done_ids else 'завершён'
    print(f"  последнее действие: [{name}] {str(arg)[:90]} — {status}")

# последняя in_progress тудушка
for d in reversed(events):
    if d['type']=='tool/call' and d.get('data',{}).get('name')=='todo_write':
        try:
            todos=json.loads(d['data'].get('arguments','{}')).get('todos',[])
            for td in todos:
                if td.get('status')=='in_progress':
                    print('  СЕЙЧАС ДЕЛАЕТ:', td.get('content','')[:80])
        except Exception: pass
        break

# пиньин/компакция health
comp=[d for d in events if d['type']=='compaction/start']
print(f"  компакций за сессию: {len(comp)}")
PYEOF
  echo "  ──────────────────────────────────────────────────────"
  echo "  обновление через 3с · Ctrl+C — выход"
  sleep 3
done
