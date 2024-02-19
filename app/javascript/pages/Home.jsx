import React, { useEffect, useState } from "react";

export default function HomePage() {
  const [appVersion, setAppVersion] = useState(null);

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
    </div>
  )
}