set -x
mkdir -p out/rq out/sherpa
curl -sSL -o rq.tgz https://pub.dev/api/archives/recite_quran-1.0.3.tar.gz && tar -xzf rq.tgz -C out/rq
curl -sSL https://pub.dev/api/packages/recite_quran > out/rq/_pub.json
curl -sSL https://pub.dev/api/packages/sherpa_onnx > out/sherpa/_pub.json
curl -sSL https://pub.dev/api/packages/record > out/sherpa/_record_pub.json
ls -laR out | head -300 > out/_ls.txt
