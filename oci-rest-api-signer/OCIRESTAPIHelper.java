import com.google.common.collect.ImmutableList;
import com.google.common.collect.ImmutableMap;
import com.google.common.hash.Hashing;
import org.tomitribe.auth.signatures.PEM;
import org.tomitribe.auth.signatures.Signature;
import org.tomitribe.auth.signatures.Signer;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.security.PrivateKey;
import java.security.spec.InvalidKeySpecException;
import java.text.SimpleDateFormat;
import java.util.*;

/**
 * Oracle Cloud Infrastructure (OCI) Advanced HTTP Signature for OCI REST API integration in PL/SQL.
 *
 * @see <a href="https://docs.cloud.oracle.com/iaas/Content/API/Concepts/signingrequests.htm#Java">Java sample code</a>
 * @version 1.0
 * @author loiclefevre
 */
public final class OCIRESTAPIHelper {

    public static String about() {
        return "Oracle Cloud Infrastructure REST API Helper - (c) Oracle 2018";
    }

    private static PrivateKey loadPrivateKey(String privateKey) {
        try (InputStream privateKeyStream = new ByteArrayInputStream(privateKey.getBytes(StandardCharsets.UTF_8))) {
            return PEM.readPrivateKey(privateKeyStream);
        } catch (InvalidKeySpecException e) {
            throw new RuntimeException("Invalid format for private key");
        } catch (IOException e) {
            throw new RuntimeException("Failed to load private key");
        }
    }

    private static final Map<String, Signer> GET_SIGNERS = new HashMap<>();
    private static final Map<String, Signer> HEAD_SIGNERS = new HashMap<>();
    private static final Map<String, Signer> DELETE_SIGNERS = new HashMap<>();
    private static final Map<String, Signer> PUT_SIGNERS = new HashMap<>();
    private static final Map<String, Signer> POST_SIGNERS = new HashMap<>();

    private static final SimpleDateFormat DATE_FORMAT;
    private static final String SIGNATURE_ALGORITHM = "rsa-sha256";
    private static final Map<String, List<String>> REQUIRED_HEADERS;

    static {
        DATE_FORMAT = new SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss zzz", Locale.US);
        DATE_FORMAT.setTimeZone(TimeZone.getTimeZone("GMT"));
        REQUIRED_HEADERS = ImmutableMap.<String, List<String>>builder()
                .put("get", ImmutableList.of("date", "(request-target)", "host"))
                .put("head", ImmutableList.of("date", "(request-target)", "host"))
                .put("delete", ImmutableList.of("date", "(request-target)", "host"))
                .put("put", ImmutableList.of("date", "(request-target)", "host", "content-length", "content-type", "x-content-sha256"))
                .put("post", ImmutableList.of("date", "(request-target)", "host", "content-length", "content-type", "x-content-sha256"))
                .build();
    }


    private static String commonSignRequest(String method,
                                            Map<String, Signer> signerCache,
                                            String dateHeader,
                                            String path,
                                            String hostHeader,
                                            String compartmentOCID,
                                            String administratorOCID,
                                            String administratorKeyFingerprint,
                                            String privateKeyString) throws IOException {
        final String apiKey = compartmentOCID + "/" + administratorOCID + "/" + administratorKeyFingerprint;

        Signer signer = signerCache.get(apiKey);

        if (signer == null) {
            final PrivateKey privateKey = loadPrivateKey(privateKeyString);

            final Signature signature = new Signature(apiKey, SIGNATURE_ALGORITHM, null, REQUIRED_HEADERS.get(method));
            signer = new Signer(privateKey, signature);

            signerCache.put(apiKey, signer);
        }

        final Map<String, String> headers = new HashMap<>();
        headers.put("date", dateHeader);
        headers.put("host", hostHeader);

        return signer.sign(method, path, headers).toString();

    }

    private static String advancedSignRequest(String method,
                                              Map<String, Signer> signerCache,
                                              String dateHeader,
                                              String path,
                                              String hostHeader,
                                              String body,
                                              String compartmentOCID,
                                              String administratorOCID,
                                              String administratorKeyFingerprint,
                                              String privateKeyString) throws IOException {
        final String apiKey = compartmentOCID + "/" + administratorOCID + "/" + administratorKeyFingerprint;

        Signer signer = signerCache.get(apiKey);

        if (signer == null) {
            final PrivateKey privateKey = loadPrivateKey(privateKeyString);

            final Signature signature = new Signature(apiKey, SIGNATURE_ALGORITHM, null, REQUIRED_HEADERS.get(method));
            signer = new Signer(privateKey, signature);

            signerCache.put(apiKey, signer);
        }

        final Map<String, String> headers = new HashMap<>();
        headers.put("date", dateHeader);
        headers.put("host", hostHeader);
        headers.put("content-type", "application/json");
        headers.put("content-length", Integer.toString(body.length()));
        headers.put("x-content-sha256", calculateSHA256(body.getBytes(StandardCharsets.UTF_8)));

        return signer.sign(method, path, headers).toString();

    }

    /**
     * Signs a GET request.
     *
     * @param dateHeader                  the date and time of the request
     * @param path                        the path
     * @param hostHeader                  the host HTTP header
     * @param compartmentOCID             the compartment OCID
     * @param administratorOCID           the administrator OCID
     * @param administratorKeyFingerprint the administrator key fingerprint
     * @param privateKeyString            the private key
     * @return the advanced HTTP signature for the GET request
     * @throws IOException in case of problem reading the private key
     */
    public static String signGetRequest(String dateHeader,
                                        String path,
                                        String hostHeader,
                                        String compartmentOCID,
                                        String administratorOCID,
                                        String administratorKeyFingerprint,
                                        String privateKeyString) throws IOException {
        return commonSignRequest("get", GET_SIGNERS, dateHeader, path, hostHeader, compartmentOCID, administratorOCID, administratorKeyFingerprint, privateKeyString);
    }

    /**
     * Signs a HEAD request.
     *
     * @param dateHeader                  the date and time of the request
     * @param path                        the path
     * @param hostHeader                  the host HTTP header
     * @param compartmentOCID             the compartment OCID
     * @param administratorOCID           the administrator OCID
     * @param administratorKeyFingerprint the administrator key fingerprint
     * @param privateKeyString            the private key
     * @return the advanced HTTP signature for the HEAD request
     * @throws IOException in case of problem reading the private key
     */
    public static String signHeadRequest(String dateHeader,
                                         String path,
                                         String hostHeader,
                                         String compartmentOCID,
                                         String administratorOCID,
                                         String administratorKeyFingerprint,
                                         String privateKeyString) throws IOException {
        return commonSignRequest("head", HEAD_SIGNERS, dateHeader, path, hostHeader, compartmentOCID, administratorOCID, administratorKeyFingerprint, privateKeyString);
    }

    /**
     * Signs a DELETE request.
     *
     * @param dateHeader                  the date and time of the request
     * @param path                        the path
     * @param hostHeader                  the host HTTP header
     * @param compartmentOCID             the compartment OCID
     * @param administratorOCID           the administrator OCID
     * @param administratorKeyFingerprint the administrator key fingerprint
     * @param privateKeyString            the private key
     * @return the advanced HTTP signature for the DELETE request
     * @throws IOException in case of problem reading the private key
     */
    public static String signDeleteRequest(String dateHeader,
                                           String path,
                                           String hostHeader,
                                           String compartmentOCID,
                                           String administratorOCID,
                                           String administratorKeyFingerprint,
                                           String privateKeyString) throws IOException {
        return commonSignRequest("delete", DELETE_SIGNERS, dateHeader, path, hostHeader, compartmentOCID, administratorOCID, administratorKeyFingerprint, privateKeyString);
    }

    /**
     * Signs a PUT request.
     *
     * @param dateHeader                  the date and time of the request
     * @param path                        the path
     * @param hostHeader                  the host HTTP header
     * @param body                        the message body
     * @param compartmentOCID             the compartment OCID
     * @param administratorOCID           the administrator OCID
     * @param administratorKeyFingerprint the administrator key fingerprint
     * @param privateKeyString            the private key
     * @return the advanced HTTP signature for the PUT request
     * @throws IOException in case of problem reading the private key
     */
    public static String signPutRequest(String dateHeader,
                                        String path,
                                        String hostHeader,
                                        String body,
                                        String compartmentOCID,
                                        String administratorOCID,
                                        String administratorKeyFingerprint,
                                        String privateKeyString) throws IOException {
        return advancedSignRequest("put", PUT_SIGNERS, dateHeader, path, hostHeader, body, compartmentOCID, administratorOCID, administratorKeyFingerprint, privateKeyString);
    }

    /**
     * Signs a POST request.
     *
     * @param dateHeader                  the date and time of the request
     * @param path                        the path
     * @param hostHeader                  the host HTTP header
     * @param body                        the message body
     * @param compartmentOCID             the compartment OCID
     * @param administratorOCID           the administrator OCID
     * @param administratorKeyFingerprint the administrator key fingerprint
     * @param privateKeyString            the private key
     * @return the advanced HTTP signature for the POST request
     * @throws IOException in case of problem reading the private key
     */
    public static String signPostRequest(String dateHeader,
                                         String path,
                                         String hostHeader,
                                         String body,
                                         String compartmentOCID,
                                         String administratorOCID,
                                         String administratorKeyFingerprint,
                                         String privateKeyString) throws IOException {
        return advancedSignRequest("post", POST_SIGNERS, dateHeader, path, hostHeader, body, compartmentOCID, administratorOCID, administratorKeyFingerprint, privateKeyString);
    }

    /**
     * Calculate the Base64-encoded string representing the SHA256 of a request body
     *
     * @param body The request body to hash
     */
    private static String calculateSHA256(final byte[] body) {
        final byte[] hash = Hashing.sha256().hashBytes(body).asBytes();
        return Base64.getEncoder().encodeToString(hash);
    }
}
