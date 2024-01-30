import React, { useEffect, useState } from 'react';
import styled from 'styled-components';
import SearchBar from './SearchBar';

export default function ResourceList() {
  const [resources, setResources] = useState([]);
  const [filteredResources, setFilteredResources] = useState([]);
  const [pageNumber, setPageNumber] = useState(1);

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
      setResources(data.concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data));
      // setResources(data);
      setFilteredResources(data);
    })();
  }, []);

  function handleIdentifierSearch(identifier) {
    console.log('Looking for id ' + identifier);
    if(identifier === '') {
      setFilteredResources(resources);
    } else {
      setFilteredResources(resources.filter((resource) => resource.identifier === identifier));
      setPageNumber(1);
    }
  }

  function handleStatusFilter(status) {
    console.log('Filtering by status ' + status)
    if(status === 'Any') {
      setFilteredResources(resources);
    } else  {
      if(status === 'undefined') {
        status = undefined
      }
      setFilteredResources(resources.filter((resource) => resource.status === status));
      setPageNumber(1);
    }
  }

  function nextPage() {
    if(pageNumber * 50 < filteredResources.length) {
      setPageNumber(pageNumber + 1);
    }
  }
  
  function prevPage() {
    if(pageNumber > 1) {
      setPageNumber(pageNumber - 1);
    }
  }

  const TableContainer = styled.div`
    height: 100%;
  `

  return (
    <div>
      <SearchBar 
        filterChoices={[...new Set(resources.map((resource) => {return resource.status}))]}
        onSearch={handleIdentifierSearch}
        onFilter={handleStatusFilter}
      />
      <label>{((pageNumber - 1) * 50 + 1) + ' - ' + (Math.min(pageNumber * 50, filteredResources.length)) + ' of ' + filteredResources.length}</label>
      <button onClick={prevPage}>prev</button>
      <button onClick={nextPage}>next</button>
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
            {filteredResources.slice((pageNumber - 1) * 50, pageNumber * 50).map((resource) => 
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
          </tbody>
        </table>
        {/* <ol>{resources.map((resource) => <li key={resource.identifier}>{JSON.stringify(resource)}</li>)}</ol> */}
      </TableContainer>
      <label>{((pageNumber - 1) * 50 + 1) + ' - ' + (Math.min(pageNumber * 50, filteredResources.length)) + ' of ' + filteredResources.length}</label>
      <button onClick={prevPage}>prev</button>
      <button onClick={nextPage}>next</button>
    </div>
  );
}