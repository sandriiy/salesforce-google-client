# Permissions

<p>
Access to Google Drive functionality and configuration is controlled through permission sets.
Assign permissions based on the user’s role and responsibilities.
</p>

<h2>Permission sets</h2>

<ul>
  <li>
    <strong>Google Cloud Client User</strong><br>
    Grants access to all operational features. Only users with this permission can actively operate on Google Drive files.
  </li>

  <li>
    <strong>Google Cloud Client Admin</strong><br>
    Grants access <strong>only</strong> to administrative and configuration features. This permission does <strong>not</strong> grant access to day-to-day file operations.
  </li>

  <li>
    <strong>Google Cloud Client User &amp; Admin</strong> (Permission Group)<br>
    A combined permission group for users who need:
    <ul>
      <li>Full operational access to Google Drive files</li>
      <li>Full administrative access to configuration and integration settings</li>
    </ul>
    <p>
      This is typically assigned to technical leads or system owners.
    </p>
  </li>
</ul>

<h2>How to assign</h2>

<ol>
  <li>Go to <strong>Setup → Permission Sets</strong> or <strong>Permission Set Groups</strong></li>
  <li>
    Assign one of the following:
    <ul>
      <li><strong>Google Cloud Client User</strong></li>
      <li><strong>Google Cloud Client Admin</strong></li>
      <li><strong>Google Cloud Client User &amp; Admin</strong> (recommended when both are required)</li>
    </ul>
  </li>
  <li>
    Verify access by opening the <strong>Google Client</strong> app:
    <ul>
      <li>Users should be able to load and operate on files</li>
      <li>Admins should be able to access configuration pages</li>
    </ul>
  </li>
</ol>