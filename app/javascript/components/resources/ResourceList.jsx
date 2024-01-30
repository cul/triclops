import React, { useEffect, useState } from 'react';
import styled from 'styled-components';
import SearchBar from './SearchBar';

export default function ResourceList() {
  const [resources, setResources] = useState([]);
  const [filteredResources, setFilteredResources] = useState([]);

  useEffect(() => {
    (async () => {
      const response = await fetch(
        '/api/v1/resources',
        {
          headers: {
            'Authorization': 'Token changethis'
          }
        });
      const data = await response.json();
      setResources(data);
      setFilteredResources(data);
    })();
  }, []);

  function handleIdentifierSearch(identifier) {
    console.log('Looking for id ' + identifier);
    if(identifier === '') {
      setFilteredResources(resources);
    } else {
      setFilteredResources(resources.filter((resource) => resource.identifier === identifier));
    }
  }

  function handleStatusFilter(status) {
    console.log('Filtering by status ' + status)
    if(status === 'Any') {
      setFilteredResources(resources);
    } else  {
      setFilteredResources(resources.filter((resource) => resource.status === status));
    }
  }

  const TableContainer = styled.div`
    height: 100%;
  `

  console.log(filteredResources);
  return (
    <div>
      <SearchBar onSearch={handleIdentifierSearch} onFilter={handleStatusFilter}/>
      <TableContainer>
        <table className="table table-dark table-bordered table-striped">
          <thead>
            <tr>
              <th>Identifier</th>
              <th>Source URI</th>
              <th>Width</th>
              <th>Height</th>
              <th>Featured Region</th>
              <th>PCDM Type</th>
              <th>Status</th>
              <th>Error Message</th>
            </tr>
          </thead>
          <tbody>
            {filteredResources.map((resource) => 
              <tr key={resource.identifier}>
                <td>{resource.identifier}</td>
                <td>{resource.source_uri}</td>
                <td>{resource.width}</td>
                <td>{resource.height}</td>
                <td>{resource.featured_region}</td>
                <td>{resource.pcdm_type}</td>
                <td>{resource.status}</td>
                <td>{resource.error_message}</td>
              </tr>
            )}
            {console.log(filteredResources)}
          </tbody>
        </table>
        {/* <ol>{resources.map((resource) => <li key={resource.identifier}>{JSON.stringify(resource)}</li>)}</ol> */}
      </TableContainer>
    </div>
  );
}