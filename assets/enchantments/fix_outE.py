import re, os

# 1. Читаем listE.md и собираем все ключи (левая часть до дефиса)
listE_keys = set()
if os.path.exists("listE.md"):
    with open("listE.md", "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if not line or "-" not in line:
                continue
            # Берём левую часть до дефиса
            raw_key = line.split("-", 1)[0].strip().strip("[]").upper()
            listE_keys.add(raw_key)

print(f"[+] Открыли listE.md, загружено ключей: {len(listE_keys)}")

# 2. Читаем lsl.md
if not os.path.exists("lsl.md"):
    print("[!] Ошибка: файл lsl.md не найден!")
    exit(1)

with open("lsl.md", "r", encoding="utf-8") as f:
    content = f.read()

# Разбиваем lsl.md на блоки
raw_blocks = re.split(r'\n(?=\[[a-zA-Z0-9_]+\])', content)

outE_blocks = []
found_count = 0

for block in raw_blocks:
    block = block.strip()
    if not block:
        continue
    
    # Ищем id = "PERK_..." или заголовок [PERK_...]
    id_match = re.search(r'id\s*=\s*["\']([^"\']+)["\']', block)
    key_match = re.match(r'^\[([a-zA-Z0-9_]+)\]', block)
    
    perk_id = ""
    if id_match:
        perk_id = id_match.group(1).upper()
    elif key_match:
        perk_id = key_match.group(1).upper()
        
    # Сверяем ID с listE.md
    if perk_id:
        if perk_id in listE_keys:
            found_count += 1
        else:
            outE_blocks.append(block)
    else:
        # Если ID не найден вовсе, на всякий случай отправляем в outE
        outE_blocks.append(block)

# 3. Сохраняем в outE.md
with open("outE.md", "w", encoding="utf-8") as f:
    f.write("\n\n".join(outE_blocks) + "\n")

print(f"[+] Найдено совпадений с listE.md: {found_count}")
print(f"[+] Выгружено в outE.md (отсутствуют в listE.md): {len(outE_blocks)}")
