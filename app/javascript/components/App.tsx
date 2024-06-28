import React, { useState, useEffect } from 'react';

const App = () => {
  const [appVersion, setAppVersion] = useState<string | null>(null);
  const [userSignedIn, setUserSignedIn] = useState<boolean>(false);

  useEffect(() => {
    setAppVersion(document.body.getAttribute('data-app-version'));
    setUserSignedIn(document.body.getAttribute('data-user-signed-in') == 'true');
  }, [appVersion])

  if (!appVersion) {
    return 'Loading...';
  }

  function renderUserSignInLinks() {
    return userSignedIn
      ? (
        <form action="/users/sign_out" method="post">
          <input type="hidden" name="_method" value="delete" />
          <input type="hidden"
            name={
              document.head.querySelector("[name='csrf-param']").content
            }
            value={
              document.head.querySelector("[name='csrf-token']").content
            }
          />
          <input type="submit" name="commit" value="Sign out" />
        </form>
      )
      : <a href="/users/sign_in">Sign in</a>;
  }

  return (
    <div>
      <h1>Triclops</h1>
      <p>{`Version ${appVersion}`}</p>
      {renderUserSignInLinks()}
    </div>
  );
};

export default App;
