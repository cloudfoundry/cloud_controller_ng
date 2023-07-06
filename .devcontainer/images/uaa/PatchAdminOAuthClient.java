import java.io.File;

import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import javax.xml.xpath.XPath;
import javax.xml.xpath.XPathConstants;
import javax.xml.xpath.XPathFactory;

import org.w3c.dom.Document;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.InputSource;

public class PatchAdminOAuthClient {

  public static void main(String[] args) throws Exception {
    if (args.length != 1) {
      System.err.println("Expecting exactly 1 argument.");
      System.exit(1);
    }
    String xmlFile = args[0];

    Document doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(new InputSource(xmlFile));

    XPath xpath = XPathFactory.newInstance().newXPath();
    NodeList nodes = (NodeList)xpath.evaluate("//entry[@key='admin']/map/entry[@key='authorities']", doc, XPathConstants.NODESET);
    if (nodes.getLength() != 1) {
      System.err.println("Expecting exactly 1 matching node.");
      System.exit(1);
    }
    Node value = nodes.item(0).getAttributes().getNamedItem("value");

    value.setNodeValue(value.getNodeValue().concat(",password.write"));

    TransformerFactory.newInstance().newTransformer().transform(new DOMSource(doc), new StreamResult(new File(xmlFile)));
  }
}