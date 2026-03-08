#/bin/env sh

cp -r ./essent-master ./essent-dedup
cp -r ./essent-master ./essent-dedup-no-locality
cp -r ./essent-master ./essent-po

cp -r ./essent/master ./essent-master/essent
cp -r ./essent/dedup ./essent-dedup/essent
cp -r ./essent/dedup-nl ./essent-dedup-no-locality/essent
cp -r ./essent/po ./essent-po/essent
