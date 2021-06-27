.PHONY: setup
setup: ## docker-compose run --rm app bundle install
	docker-compose run --rm app bundle install

.PHONY: run
run: ## docker-compose run --rm app ruby main.rb ${url}
	docker-compose run --rm app ruby main.rb ${url}

.PHONY: bash
bash: ## docker-compose run --rm app bash
	docker-compose run --rm app bash

.PHONY: clean
clean: ## docker run --rm
	docker-compose down --volume


################################################################################
# Utility-Command help
################################################################################
.DEFAULT_GOAL := help

################################################################################
# マクロ
################################################################################
# Makefileの中身を抽出してhelpとして1行で出す
# $(1): Makefile名
define help
  grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(1) \
  | grep --invert-match "## non-help" \
  | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
endef
################################################################################
# タスク
################################################################################
.PHONY: help
help: ## Make タスク一覧
	@echo '######################################################################'
	@echo '# Makeタスク一覧'
	@echo '# $$ make XXX'
	@echo '# or'
	@echo '# $$ make XXX --dry-run'
	@echo '######################################################################'
	@echo $(MAKEFILE_LIST) \
	| tr ' ' '\n' \
	| xargs -I {included-makefile} $(call help,{included-makefile})
