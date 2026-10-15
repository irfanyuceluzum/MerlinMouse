#!/usr/bin/env bash
# denetle.sh — orkestra-kur skill'inin genel denetim betiği.
# Projede .claude/bin/denetle.sh olarak durur; hangi değişiklikte hangi komutun
# koşacağını projenin .claude/denetim.conf dosyasından okur. Ajanlara yalnız
# özet basar; tam çıktılar .claude/tmp/<ad>.log içinde kalır.
# macOS'taki bash 3.2 ile uyumludur (ilişkisel dizi, mapfile kullanmaz).
#
# Kullanım:
#   denetle.sh --baseline [ad,ad]  İş başlamadan önce başlangıç ölçümü
#                                  (verilmezse tüm bloklar; ana oturum çalıştırır)
#   denetle.sh --hizli             implementer: değişen yollara eşleşen blokların
#                                  "hizli" komutları
#   denetle.sh                     verifier: eşleşen blokların "tam" komutları
#
# Çıkış: 0 = geçti, 1 = en az bir denetim kaldı, 2 = kurulum/kullanım hatası.

set -o pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "Git deposu değil; denetim yapılamaz."; exit 2; }
cd "$ROOT" || exit 2
CONF="$ROOT/.claude/denetim.conf"
TMP="$ROOT/.claude/tmp"
BASE="$TMP/baseline"
[ -f "$CONF" ] || { echo ".claude/denetim.conf yok; önce orkestra kurulumu yapılmalı."; exit 2; }
mkdir -p "$TMP" "$BASE"

MOD=tam; SECILI=""
case "${1:-}" in
  --baseline) MOD=baseline; SECILI="${2:-}" ;;
  --hizli)    MOD=hizli ;;
  "")         ;;
  *) echo "Bilinmeyen seçenek: $1 (--baseline [ad,ad] | --hizli | boş)"; exit 2 ;;
esac

# --- denetim.conf okuma: [ad] blokları; desen / hizli / tam anahtarları ---
ADLAR=(); DESENLER=(); HIZLILAR=(); TAMLAR=()
n=-1
while IFS= read -r satir || [ -n "$satir" ]; do
  satir="${satir%$'\r'}"
  [[ $satir =~ ^[[:space:]]*(#|$) ]] && continue
  if [[ $satir =~ ^[[:space:]]*\[([A-Za-z0-9_.-]+)\][[:space:]]*$ ]]; then
    n=$((n + 1)); ADLAR[$n]="${BASH_REMATCH[1]}"
    DESENLER[$n]=""; HIZLILAR[$n]=""; TAMLAR[$n]=""
    continue
  fi
  if [ $n -ge 0 ] && [[ $satir =~ ^[[:space:]]*(desen|hizli|tam)[[:space:]]*= ]]; then
    anahtar="${BASH_REMATCH[1]}"; deger="${satir#*=}"
    deger="${deger#"${deger%%[![:space:]]*}"}"
    case $anahtar in
      desen) DESENLER[$n]="$deger" ;;
      hizli) HIZLILAR[$n]="$deger" ;;
      tam)   TAMLAR[$n]="$deger" ;;
    esac
  fi
done <"$CONF"
[ $n -ge 0 ] || { echo "denetim.conf içinde [blok] yok."; exit 2; }

# Bulgu satırlarını karşılaştırılabilir yap: sayıları (satır no, süre) sil.
bulgu() {
  grep -aiE 'error|warning|warn |fail|❌|✗|exception' "$1" \
    | sed -E 's/[0-9]+/N/g; s/^[[:space:]]+//' | LC_ALL=C sort -u
}

# Desenler dosya adına genişlemesin diye glob kapalı eşleştir.
eslesir() {  # eslesir <dosya> <desenler>
  local p sonuc=1
  set -f
  for p in $2; do
    if [[ $1 == $p ]]; then sonuc=0; break; fi
  done
  set +f
  return $sonuc
}

FAIL=0
calistir() {  # calistir <ad> <komut>
  local ad="$1" komut="$2" log="$TMP/$1.log" rc yeni
  ( cd "$ROOT" && bash -c "$komut" ) >"$log" 2>&1; rc=$?
  if [ "$MOD" = baseline ]; then
    echo "$rc" >"$BASE/$ad.rc"; bulgu "$log" >"$BASE/$ad.bulgu"
    if [ $rc -eq 0 ]; then echo "  $ad: yeşil"; else echo "  $ad: kırmızı (işten önce var olan durum)"; fi
    return
  fi
  if [ $rc -eq 0 ]; then
    echo "✅ $ad — $(grep -av '^[[:space:]]*$' "$log" | tail -n 1 | cut -c1-120)"
    return
  fi
  bulgu "$log" >"$TMP/$ad.bulgu"
  if [ -f "$BASE/$ad.rc" ] && [ "$(cat "$BASE/$ad.rc")" != 0 ]; then
    yeni="$(LC_ALL=C comm -13 "$BASE/$ad.bulgu" "$TMP/$ad.bulgu")"
    if [ -z "$yeni" ]; then
      echo "⚠️  $ad — işten önce de kırmızıydı; yeni bulgu yok"
      return
    fi
    echo "❌ $ad — başlangıca göre yeni bulgu (kayıt: .claude/tmp/$ad.log):"
    echo "$yeni" | head -n 15
  else
    if [ -f "$BASE/$ad.rc" ]; then
      echo "❌ $ad — işten önce yeşildi, şimdi kırmızı (kayıt: .claude/tmp/$ad.log):"
    else
      echo "❌ $ad — kırmızı, başlangıç ölçümü yok (kayıt: .claude/tmp/$ad.log):"
    fi
    if [ -s "$TMP/$ad.bulgu" ]; then head -n 15 "$TMP/$ad.bulgu"; else tail -n 10 "$log"; fi
  fi
  FAIL=1
}

# --- Başlangıç ölçümü ---
if [ "$MOD" = baseline ]; then
  rm -f "$BASE"/*
  echo "Başlangıç ölçümü:"
  i=0
  while [ $i -le $n ]; do
    ad="${ADLAR[$i]}"; komut="${TAMLAR[$i]:-${HIZLILAR[$i]}}"; i=$((i + 1))
    case ",$SECILI," in ",,") ;; *",$ad,"*) ;; *) continue ;; esac
    case "$komut" in ""|*"{dosyalar}"*|*"{yeni}"*) continue ;; esac
    calistir "$ad" "$komut"
  done
  exit 0
fi

# --- Değişen ve yeni dosyalar (silinenler ve .claude/tmp hariç) ---
DEGISEN=(); YENI=()
while IFS= read -r s; do
  d="${s:0:2}"; y="${s:3}"; y="${y##* -> }"; y="${y#\"}"; y="${y%\"}"
  case "$y" in .claude/tmp/*) continue ;; esac
  case "$d" in *D*) continue ;; esac
  DEGISEN[${#DEGISEN[@]}]="$y"
  case "$d" in "??"|A*) YENI[${#YENI[@]}]="$y" ;; esac
done < <(git status --porcelain --untracked-files=all)

if [ ${#DEGISEN[@]} -eq 0 ]; then echo "Değişiklik yok."; exit 0; fi
echo "Değişen dosya: ${#DEGISEN[@]} (yeni: ${#YENI[@]})"

KAPSANDI=$'\n'
i=0
while [ $i -le $n ]; do
  ad="${ADLAR[$i]}"; desen="${DESENLER[$i]}"
  if [ "$MOD" = hizli ]; then komut="${HIZLILAR[$i]}"; else komut="${TAMLAR[$i]:-${HIZLILAR[$i]}}"; fi
  i=$((i + 1))
  ESL=(); ESL_YENI=()
  for f in "${DEGISEN[@]}"; do
    if eslesir "$f" "$desen"; then ESL[${#ESL[@]}]="$f"; KAPSANDI="$KAPSANDI$f"$'\n'; fi
  done
  [ ${#ESL[@]} -eq 0 ] && continue
  if [ ${#YENI[@]} -gt 0 ]; then
    for f in "${YENI[@]}"; do eslesir "$f" "$desen" && ESL_YENI[${#ESL_YENI[@]}]="$f"; done
  fi
  if [ -z "$komut" ]; then
    [ "$MOD" = hizli ] && echo "⏭  $ad — hızlı komutu yok; tam denetimde (verifier) koşar"
    continue
  fi
  case "$komut" in
    *"{yeni}"*)
      [ ${#ESL_YENI[@]} -eq 0 ] && continue
      komut="${komut//\{yeni\}/$(printf '%q ' "${ESL_YENI[@]}")}" ;;
  esac
  komut="${komut//\{dosyalar\}/$(printf '%q ' "${ESL[@]}")}"
  calistir "$ad" "$komut"
done

KAPSANMAYAN=()
for f in "${DEGISEN[@]}"; do
  case "$KAPSANDI" in *$'\n'"$f"$'\n'*) ;; *) KAPSANMAYAN[${#KAPSANMAYAN[@]}]="$f" ;; esac
done
if [ ${#KAPSANMAYAN[@]} -gt 0 ]; then
  echo "ℹ️  Denetimi tanımlı olmayan değişen dosya: ${#KAPSANMAYAN[@]} — ${KAPSANMAYAN[*]:0:5}"
fi

exit $FAIL
