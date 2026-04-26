#!/bin/bash

# 测试 qwen3.6 系列所有可能的变体名称

echo "=========================================="
echo "测试 qwen3.6 系列模型变体"
echo "=========================================="
echo ""

# 定义所有可能的模型名称变体
variants=(
	"qwen3.6-plus"
	"qwen3.6"
	"qwen3-6-plus"
	"qwen-3.6-plus"
	"qwen3.6-coder"
	"qwen3.6-coder-plus"
	"qwen3-6-coder"
	"qwen3-6-coder-plus"
	"qwen-coder-3.6"
	"qwen-coder-3.6-plus"
	"qwen3.6p"
	"qwen3.6-plus-2025"
	"qwen3.6-plus-latest"
	"qwen3.6-turbo"
	"qwen3.6-chat"
)

echo "将测试以下模型名称变体："
for v in "${variants[@]}"; do
	echo "  - $v"
done
echo ""
echo "开始测试..."
echo ""

# 测试每个变体
for model in "${variants[@]}"; do
	echo "测试: bailian_coding/$model"
	result=$(opencode run --model "bailian_coding/$model" "你好" 2>&1 | head -5)

	# 检查是否包含错误
	if echo "$result" | grep -q "ProviderModelNotFoundError"; then
		echo "  ❌ 不支持"
	elif echo "$result" | grep -q "Model not found"; then
		echo "  ❌ 不支持"
	elif echo "$result" | grep -q "build"; then
		echo "  ✅ 可用！"
		echo "  响应: $(echo "$result" | tail -n 1)"
	else
		echo "  ? 未知状态"
		echo "  输出: $result"
	fi
	echo ""
done

echo "=========================================="
echo "测试完成"
echo "=========================================="
