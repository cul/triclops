import React, { useEffect, useState } from 'react';
import styled from 'styled-components';
import SearchBar from './SearchBar';
import { useSearchParams, useNavigate } from 'react-router-dom';

export default function ResourceList() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const [resources, setResources] = useState([]);
  const [filteredResources, setFilteredResources] = useState([]);
  const [pageState, setPageState] = useState({ pageNumber: 1, identifier: '', status: 'Any'});

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
      // setResources(data.concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data));
      // setFilteredResources(data.concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data).concat(data));
      setResources(data);
      
      let filteredData = data;
      if (pageState.identifier) { filteredData = filteredData.filter((resource) => resource.identifier === pageState.identifier); } 
      if (pageState.status === '@undefined') { filteredData = filteredData.filter((resource) => resource.status === undefined); }
        else if (pageState.status && pageState.status != 'Any') { filteredData = filteredData.filter((resource) => resource.status === pageState.status); }
      setFilteredResources(filteredData)
    })();
  }, []);

  function setURL(identifier, status, page) {
    let url = '?';
    if (identifier) { url = url + 'identifier=' + identifier + '&'};
    if (status) { url = url + 'status=' + status + '&'};
    if (page) { url = url + 'page=' + page};
    navigate(url);
  }

  function handleIdentifierSearch(identifier) {
    console.log('Looking for id ' + identifier);
  
    setURL(identifier, pageState.status, 1);
  }

  function handleStatusFilter(status) {
    if(status === 'undefined') {
      status = '@undefined'
    }
    setURL(pageState.identifier, status, 1);
    console.log('Filtering by status ' + status)
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

  const queryIdentifier = searchParams.get('identifier');
  const queryStatus = searchParams.get('status');
  const queryPage = searchParams.get('page');

  const newPageState = { ...pageState }

  console.log(filteredResources);

  if (
    (queryIdentifier && (queryIdentifier != pageState.identifier)) ||
    (queryStatus && (queryStatus != pageState.status)) ||
    (queryPage && (parseInt(queryPage) != pageState.pageNumber) && (queryPage - 1) * 50 < filteredResources.length)
  ) {

    if (queryIdentifier && (queryIdentifier != pageState.identifier)) { 
      // console.log("changing identifier from " + pageState.identifier + " to " + queryIdentifier);
      setFilteredResources(resources.filter((resource) => resource.identifier === queryIdentifier)); 
      newPageState.identifier = queryIdentifier;
    }
    if (queryStatus && (queryStatus != pageState.status)) {
      // console.log("changing status from " + pageState.status + " to " + queryStatus);
      setFilteredResources(filteredResources.filter((resource) => resource.status === queryStatus)); 
      newPageState.status = queryStatus;
    }
    if (queryPage && (queryPage != pageState.pageNumber) && queryPage * 50 < filteredResources.length) { 
      console.log("changing page number from " + pageState.pageNumber + " to " + queryPage);
      newPageState.pageNumber = queryPage;
    } else if (newPageState.identifier != pageState.identifier || newPageState.status != pageState.status) {
      // Move to page 1 if a filter param was updated and the page isn't specified
      newPageState.pageNumber = 1;
    }

    console.log(pageState);
    console.log(newPageState);
    setPageState(newPageState);
  }

  console.log(filteredResources);

  return (
    <div>
      <SearchBar 
        filterChoices={[...new Set(resources.map((resource) => {return resource.status}))]}
        onSearch={handleIdentifierSearch}
        onFilter={handleStatusFilter}
      />
      <label>{((pageState.pageNumber - 1) * 50 + 1) + ' - ' + (Math.min(pageState.pageNumber * 50, filteredResources.length)) + ' of ' + filteredResources.length}</label>
      <button onClick={prevPage}>prev</button>
      <button onClick={nextPage}>next</button>
      <TableContainer>
        <table className="table table-primary table-striped">
          <thead className='thead-dark'>
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
          <tbody className=''>
            {filteredResources.slice((pageState.pageNumber - 1) * 50, pageState.pageNumber * 50).map((resource) => 
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
      <label>{((pageState.pageNumber - 1) * 50 + 1) + ' - ' + (Math.min(pageState.pageNumber * 50, filteredResources.length)) + ' of ' + filteredResources.length}</label>
      <button onClick={prevPage}>prev</button>
      <button onClick={nextPage}>next</button>
    </div>
  );
}