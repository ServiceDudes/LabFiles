# Lab08.2 - Create certificate template on CA server

##### Create Certificate Template

1. First open the Certificate Templates Console by typing certtmpl.msc. Then select the “Workstation Authentication” template and create a duplicate.

2. Change the compatibility settings for Certificate Authority and Recipient to Windows Server 2012 R2.

3. On the General tab:
  - Give the template DSCEncryption
  - Configure the validity period 1 year

4. On the Request Handling tab:
  - Change the purpose to Encryption
  - Select the Allow private key to be exported checkbox as we need to request certificates and them export them to PFX

5. On the Crypthography tab:
  - Change the Provider Category to Legacy Cryptographic Service Provider, Determined by CSP.
  - Set the minimum key size to 2048
  - Choose Microsoft RSA SChannel Cryptographic Provider as provider

6. On the Subject Name tab:
  - Select Supply in the request

7. On the Extensions Tab:
  - Select Application Policies. Click edit and remove Client Authentication
  - Click Add and add Document Encryption
  - Click edit Key Usage and Allow key exchange only with key encryption (key encipherment)
  - Add Allow encryption of user data

8. On the Security tab:
 - Select Authenticated Users and Allow the Enroll permission

9. Now the template is finished. Select OK.

##### Add Certificate Template to Templates to Issue

1. Open the Certificate Authority console by typing certsrv.msc.

2. Navigate to the Certificate Template node, right click it and select New -> Certificate Template to Issue

3. Select the Certificate template which was created earlier and press OK.
