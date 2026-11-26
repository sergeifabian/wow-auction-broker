# Имя аддона и итогового архива
ADDON     := AuctionBroker
ARCHIVE   := $(ADDON).zip

# Что НЕ копируем в чистую папку
EXCLUDES  := --exclude='.git' --exclude='__MACOSX' --exclude='*.DS_Store' \
             --exclude='._*' --exclude='$(ADDON)' --exclude='$(ARCHIVE)' \
             --exclude='.gitignore' --exclude='LICENSE*' --exclude='COPYING*' \
             --exclude='Makefile' --exclude='makefile' --exclude='GNUmakefile'

.DEFAULT_GOAL := help
.PHONY: help package clean

# Справка по целям
help:
	@echo "Доступные команды:"
	@echo "  make package   Собрать чистую папку $(ADDON)/ и архив $(ARCHIVE)"
	@echo "  make clean     Удалить $(ADDON)/ и $(ARCHIVE)"
	@echo "  make help      Показать эту справку"

# Собрать чистую папку и заархивировать
package: clean
	@echo ">> Создаю чистую папку $(ADDON)..."
	@mkdir -p $(ADDON)
	@rsync -a $(EXCLUDES) ./ $(ADDON)/
	@echo ">> Архивирую..."
	@zip -r -X $(ARCHIVE) $(ADDON) \
		-x '*.DS_Store' -x '*/__MACOSX/*' -x '*/._*'
	@echo ">> Готово: $(ARCHIVE)"
	@echo ">> Содержимое архива:"
	@unzip -l $(ARCHIVE)
	@echo ">> Проверка на мусор..."
	@! unzip -Z1 $(ARCHIVE) | grep -E '(__MACOSX|\.DS_Store|/\._|^\._|\.git/|Makefile|\.gitignore|LICENSE|COPYING)' \
		|| (echo "!! В архиве найден мусор" && exit 1)

# Удалить результаты сборки
clean:
	@rm -rf $(ADDON) $(ARCHIVE)