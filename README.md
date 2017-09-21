# CFConfigureEmail

Simple tooling for making email configuration in CloudForms a breeze. 

This will build a new custom Automate domain containing all the instances with email addresses in their schema, with
 both to and from set the same.
 
Additionally, it includes Automate code, dialogs, and service catalog items to update to/from independently, as well
as the email signatures.

## INSTALL

Get yourself an export of the stock Datastores, and build out the .zip per:

`./createEmailDomain.rb -r ~/Projects/  CFLAB/datastore/ -d RHCEmailConfiguration -e you+cflab@yourdomain.com`

Import the created .zip file with Automate->Automate->Import Export.

Optionally, import the Service dialog and catalog items. Copy them to an appliance and:

`miqimport service_dialogs ToImport/ServiceDialog/rhc_configure_email.yml`
`miqimport service_catalog ToImport/ServiceCatalog/`

**Note:** You will want to lock that down somehow, perhaps with a prov_scope=>admin_only tag or similar.

### Todo
