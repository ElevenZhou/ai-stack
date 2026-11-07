#!/bin/bash
# 双击运行入口：调用同目录下的 ai-stack.sh
cd "$(dirname "$0")" || exit 1

clear
./ai-stack.sh "$@"
status=$?

echo
if [[ $status -ne 0 ]]; then
  echo "有失败项，请查看上面的输出和日志。"
else
  echo "全部完成。"
fi

printf "按任意键关闭窗口…"
read -n 1 -s -r
echo
exit $status
