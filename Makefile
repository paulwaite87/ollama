# Container variables
PRIMARY_CONTAINER=llama-vulkan
FIM_CONTAINER=llama-vulkan-fim
EMBED_CONTAINER=llama-vulkan-embed
MODELS_DIR=./models
COMPOSE_FILE=docker-compose.yml
HF_SITE=https://huggingface.co
export HF_TOKEN=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

.PHONY: build rebuild save_env swap_primary swap_fim swap_embed start stop restart logs ps run list shell monitor install uninstall help

## swap_primary: Swap the primary chat model (e.g., make swap_primary model=Llama-3.gguf)
swap_primary:
ifndef model
	$(error Please specify the model file name. Example: make swap_primary model=filename.gguf)
endif
	@if [ ! -f "$(MODELS_DIR)/$(model)" ]; then \
		echo "❌ Error: File '$(model)' does not exist in $(MODELS_DIR)"; \
		exit 1; \
	fi
	@echo "🔄 Setting PRIMARY_MODEL=$(model) in .env file..."
	@touch .env
	@grep -q "^PRIMARY_MODEL=" .env || echo "PRIMARY_MODEL=" >> .env
	@sed -i 's/^PRIMARY_MODEL=.*/PRIMARY_MODEL=$(model)/' .env
	@echo "🐳 Triggering rolling container upgrade..."
	docker compose up -d --remove-orphans $(PRIMARY_CONTAINER)
	@echo "✅ Success! $(PRIMARY_CONTAINER) is reloading with $(model)"

## swap_fim: Swap the autocomplete FIM model (e.g., make swap_fim model=StarCoder2.gguf)
swap_fim:
ifndef model
	$(error Please specify the model file name. Example: make swap_fim model=filename.gguf)
endif
	@if [ ! -f "$(MODELS_DIR)/$(model)" ]; then \
		echo "❌ Error: File '$(model)' does not exist in $(MODELS_DIR)"; \
		exit 1; \
	fi
	@echo "🔄 Setting FIM_MODEL=$(model) in .env file..."
	@touch .env
	@grep -q "^FIM_MODEL=" .env || echo "FIM_MODEL=" >> .env
	@sed -i 's/^FIM_MODEL=.*/FIM_MODEL=$(model)/' .env
	@echo "🐳 Triggering rolling container upgrade..."
	docker compose up -d --remove-orphans $(FIM_CONTAINER)
	@echo "✅ Success! $(FIM_CONTAINER) is reloading with $(model)"

## swap_embed: Swap the embedding model (e.g., make swap_embed model=bge-large.gguf)
swap_embed:
ifndef model
	$(error Please specify the model file name. Example: make swap_embed model=filename.gguf)
endif
	@if [ ! -f "$(MODELS_DIR)/$(model)" ]; then \
		echo "❌ Error: File '$(model)' does not exist in $(MODELS_DIR)"; \
		exit 1; \
	fi
	@echo "🔄 Setting EMBED_MODEL=$(model) in .env file..."
	@touch .env
	@grep -q "^EMBED_MODEL=" .env || echo "EMBED_MODEL=" >> .env
	@sed -i 's/^EMBED_MODEL=.*/EMBED_MODEL=$(model)/' .env
	@echo "🐳 Triggering rolling container upgrade..."
	docker compose up -d --remove-orphans $(EMBED_CONTAINER)
	@echo "✅ Success! $(EMBED_CONTAINER) is reloading with $(model)"

## save_env: Sync/reset the .env file with the baseline default models defined in docker-compose.yml
save_env:
	@echo "Extracting baseline models from $(COMPOSE_FILE)..."
	@PRIMARY_DEFAULT=$$(sed -n 's/.*PRIMARY_MODEL:-\([^}]*\).*/\1/p' $(COMPOSE_FILE)); \
	FIM_DEFAULT=$$(sed -n 's/.*FIM_MODEL:-\([^}]*\).*/\1/p' $(COMPOSE_FILE)); \
	EMBED_DEFAULT=$$(sed -n 's/.*EMBED_MODEL:-\([^}]*\).*/\1/p' $(COMPOSE_FILE)); \
	if [ -z "$$PRIMARY_DEFAULT" ] || [ -z "$$FIM_DEFAULT" ] || [ -z "$$EMBED_DEFAULT" ]; then \
		echo "❌ Error: Could not parse default models from $(COMPOSE_FILE). Check your syntax."; \
		exit 1; \
	fi; \
	echo "PRIMARY_MODEL=$$PRIMARY_DEFAULT" > .env; \
	echo "FIM_MODEL=$$FIM_DEFAULT" >> .env; \
	echo "EMBED_MODEL=$$EMBED_DEFAULT" >> .env
	@echo "📝 Generated a clean .env file based on your compose file defaults:"
	@cat .env

## start: Start the dual llama.cpp Vulkan container stack
start:
	@echo "Starting LLMs"
	@docker compose up -d

## stop: Stop the container stack
stop:
	@echo "Stopping LLMs"
	@docker compose down

## restart: Restart all containers
restart:
	docker compose restart

## build: Build images if changed
build: stop
	docker compose build

## rebuild: Rebuild all images from scratch
rebuild: stop
	docker compose build --no-cache

## logs: View live container boot and inference logs for both models
logs:
	docker compose logs -f

## ps: Show status of all stack containers
ps:
	docker compose ps

## list: List all locally downloaded GGUF models in the shared folder
list:
	@echo "Local models:"
	@ls -lh $(MODELS_DIR)/* 2>/dev/null | awk '{print $$5, "\t", $$9}' | sed 's|$(MODELS_DIR)/||' || echo "No .gguf models found."

## shell: Drop into a bash terminal inside the primary container
shell:
	docker exec -it $(PRIMARY_CONTAINER) /bin/sh

## monitor: Launch interactive host-level GPU and VRAM performance dashboard
monitor:
	@if command -v nvtop >/dev/null 2>&1; then \
		nvtop; \
	else \
		echo "nvtop is not installed. Running quick setup..."; \
		sudo apt update && sudo apt install -y nvtop && nvtop; \
	fi

## install: Download a GGUF file from Hugging Face
install:
ifndef model
	$(error Specify the HuggingFace model. Eg: make install model=Qwen3.5-9B-MTP-GGUF)
endif
	@echo "Downloading model to shared volume..."
ifdef include
	hf download ${model} --local-dir=${MODELS_DIR} --include="*${include}*" --token=${HF_TOKEN}
else
	hf download ${model} --local-dir=${MODELS_DIR} --token=${HF_TOKEN}
endif
	@echo "Download complete!"

## uninstall: Delete a specific GGUF file from the shared directory (e.g., make uninstall file=model.gguf)
uninstall:
ifndef file
	$(error Please specify the filename to delete. Example: make uninstall file=Qwen2.5-Coder-1.5B.Q8_0.gguf)
endif
	@echo "Removing $(file) from $(MODELS_DIR)..."
	rm -i $(MODELS_DIR)/$(file)

## help: Show this help menu
help:
	@echo "Available management commands:"
	@sed -n 's/^##//p' $(MAKEFILE_LIST) | awk '{printf "  \033[36m%-15s\033[0m %s\n", $$1, substr($$0, index($$0,$$2))}'
