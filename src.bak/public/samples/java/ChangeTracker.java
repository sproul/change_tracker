import java.io.*;
import java.net.*;

public class ChangeTracker {
    static String server_host_and_port = "http://slcipcn.us.oracle.com:4567";

	public static String list_files_changed_between(String cspec_set1, String cspec_set2) throws Exception {
        return ChangeTracker.execute_op("list_files_changed_between", cspec_set1, cspec_set2);
    }
	public static String list_changes_between(String cspec_set1, String cspec_set2) throws Exception {
        return ChangeTracker.execute_op("list_changes_between", cspec_set1, cspec_set2);
    }
	public static String list_bug_IDs_between(String cspec_set1, String cspec_set2) throws Exception {
        return ChangeTracker.execute_op("list_bug_IDs_between", cspec_set1, cspec_set2);
    }
	private static String urlEncodeParm(String parmName, String parmVal) throws UnsupportedEncodingException {
        return "&" + parmName + "=" + URLEncoder.encode(parmVal, "UTF-8");
    }
	private static String execute_op(String op, String cspec_set1, String cspec_set2) throws Exception {
        StringBuilder result = new StringBuilder();
        String url_string = ChangeTracker.server_host_and_port + "?pretty=true&op=" + op + urlEncodeParm("cspec_set1", cspec_set1) + urlEncodeParm("cspec_set2", cspec_set2);
        URL url = new URL(url_string);
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod("GET");
        BufferedReader rd = new BufferedReader(new InputStreamReader(conn.getInputStream()));
        String line;
        while ((line = rd.readLine()) != null) {
            result.append(line);
        }
        rd.close();
        return result.toString();
    }

	public static void main(String[] args) throws Exception {
        String cspec_set1 = "{\n"
            + "\"cspec\": \"git;git.osn.oraclecorp.com;osn/cec-server-integration;;6b5ed0226109d443732540fee698d5d794618b64\",\n"
            + "\"cspec_deps\": [\n"
            + "\"git;git.osn.oraclecorp.com;ccs/caas;master;35f9f10342391cae7fdd69f5f8ad590fba25251d\",\n"
            + "\"git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf\"\n"
            + "]\n"
            + "}\n";
        String cspec_set2 = "{\n"
            + "\"cspec_deps\": [\n"
            + "\"git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed\",\n"
            + "\"git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf\"\n"
            + "],\n"
            + "\"cspec\": \"git;git.osn.oraclecorp.com;osn/cec-server-integration;;06c85af5cfa00b0e8244d723517f8c3777d7b77e\"\n"
            + "}\n";

        System.out.println("=================================================================================================");
        System.out.println("calling list_bug_IDs_between...");
        System.out.println(list_bug_IDs_between(      cspec_set1, cspec_set2));
        System.out.println("=================================================================================================");
        System.out.println("=================================================================================================");
        System.out.println("calling list_files_changed_between...");
        System.out.println(list_files_changed_between(cspec_set1, cspec_set2));
        System.out.println("=================================================================================================");
        System.out.println("=================================================================================================");
        System.out.println("calling list_changes_between(      cspec...");
        System.out.println(list_changes_between(      cspec_set1, cspec_set2));
        System.out.println("=================================================================================================");
    }
}
