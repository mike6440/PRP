ps cax | grep Z_prp > /dev/null
if [ $? -eq 0 ]; then
  echo "Process is running."
else
  echo "Process is not running."
fi
