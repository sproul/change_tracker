import java.io.*;
import java.net.*;

public class Change_tracker {

	public static String getHTML(String urlToRead) throws Exception {
        StringBuilder result = new StringBuilder();
        URL url = new URL(urlToRead);
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

	public static void main(String[] args) throws Exception
        {
            String op = args[0];
            switch (op) {
            case :
                break;
            default:
                ;
            }
            System.out.println("main: ");
        System.out.println(getHTML(args[0]));
        }
}
    
    
