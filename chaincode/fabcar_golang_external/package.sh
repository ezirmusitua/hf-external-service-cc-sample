if [ -f fabcar-external.tgz ]; then
  rm fabcar-external.tgz
fi

tar czf fabcar-external.tgz code.tar.gz metadata.json

