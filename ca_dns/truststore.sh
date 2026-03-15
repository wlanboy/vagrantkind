keytool -importcert \
  -file ca-gmk.pem \
  -keystore gmk-truststore.p12 \
  -storetype PKCS12 \
  -alias gmk \
  -storepass changeit \
  -noprompt

keytool -importcert \
  -file ca-gmkc.pem \
  -keystore gmk-truststore.p12 \
  -storetype PKCS12 \
  -alias gmkc \
  -storepass changeit \
  -noprompt

keytool -list -keystore gmk-truststore.p12 -storepass changeit
