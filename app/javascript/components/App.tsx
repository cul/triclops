import React, { useState, useEffect } from 'react';
import ResourceList from './resources/ResourceList';

const App = () => {
  const [appVersion, setAppVersion] = useState<string | null>(null);

  useEffect(() => {
    setAppVersion(document.body.getAttribute('data-app-version'));
  }, [appVersion])

  if (!appVersion) {
    return 'Loading...';
  }

  return (
    <div>
      <h1>Triclops</h1>
      <p>{`Version ${appVersion}`}</p>
      <ResourceList />
    </div>
  );
};

export default App;
