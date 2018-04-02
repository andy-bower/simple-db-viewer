<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" indent="yes"/>
  <xsl:template match="/result">
    <html>
      <head>
	<title>Simple database viewer</title>
	<link rel="stylesheet" type="text/css" href="user/knosoc.css"/>
      </head>
      <body>
	<xsl:apply-templates select="table"/>
      </body>
    </html>
  </xsl:template>

  <xsl:template match="table">
    <table class="data">
      <xsl:apply-templates select="heading|record"/>
    </table>
  </xsl:template>
  
  <xsl:template match="heading|record">
    <tr>
      <xsl:apply-templates select="field|value"/>
    </tr>
  </xsl:template>

  <xsl:template match="field">
    <th>
      <xsl:apply-templates select="text()"/>
    </th>
  </xsl:template>

  <xsl:template match="value[@href]">
    <td>
      <a href="{@href}">
	<xsl:apply-templates select="text()"/>
      </a>
    </td>
  </xsl:template>

  <xsl:template match="value">
    <td>
      <xsl:apply-templates select="text()"/>
    </td>
  </xsl:template>

</xsl:stylesheet>
