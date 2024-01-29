import React, { useState, useEffect } from 'react';
import SearchBar from './resources/SearchBar';
import ResourceList from './resources/ResourceList';
import '../stylesheets/triclops_v1.scss'; // app css entry point

const App = () => {
  const [appVersion, setAppVersion] = useState<string | null>(null);
  const [filterText, setFilterText] = useState('');

  useEffect(() => {
    setAppVersion(document.body.getAttribute('data-app-version'));
  }, [appVersion])
  

  function handleFilter(text) {
    setFilterText(text);
    console.log('filtering by ' + text);
  }

  if (!appVersion) {
    return 'Loading...';
  }

  return (
    <div>
      <h1>Triclops</h1>
      <p>{`Version ${appVersion}`}</p>
      <SearchBar onSearch={handleFilter}/>
      <ResourceList />
    </div>
  );
};

export default App;
