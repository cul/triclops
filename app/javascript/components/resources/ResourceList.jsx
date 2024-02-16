import React, { useEffect, useState } from 'react';
import styled from 'styled-components';
import SearchBar from './SearchBar';
import { useSearchParams, useNavigate } from 'react-router-dom';

const filterChoices = ['Pending', 'Processing', 'Failure', 'Ready'];

export default function ResourceList() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const [filteredResources, setFilteredResources] = useState([]);
  const [pageState, setPageState] = useState({ identifier: '', status: 'Any', pageNumber: 1, per_page: 50 });
  const [lastPage, setLastPage] = useState(false);

  useEffect(() => {
    let fetch_url ='/api/v1/resources?'
    if (pageState.identifier) {fetch_url += `identifier=${pageState.identifier}&`;} 
    if (pageState.status) {fetch_url += `status=${pageState.status}&`;} 
    fetch_url += `page=${pageState.pageNumber ? pageState.pageNumber : 1}&`;
    fetch_url += `per_page=${pageState.per_page}`;
    console.log(fetch_url);
    (async () => {
      const response = await fetch(fetch_url);
      const data = await response.json();

      setFilteredResources(data['resources']);
      setLastPage(data['last_page'])
    })()
  }, [searchParams]);

  function setURL(identifier, status, page, per_page) {
    let url = '?';
    url += 'identifier=' + identifier + '&';
    url += 'status=' + status + '&';
    url += 'page=' + page + '&';
    url +='per_page=' + per_page;
    navigate(url);
  }

  function handleIdentifierSearch(identifier) {
    setURL(identifier, pageState.status, 1, pageState.per_page);
  }

  function handleStatusFilter(status) {
    if(status === 'undefined') {
      status = '@undefined'
    }
    setURL(pageState.identifier, status, 1, pageState.per_page);
  }

  function handlePerPageSet(perPage) {
    setURL(pageState.identifier, pageState.status, 1, perPage);
  }

  function nextPage() {
    if(!lastPage) {
      setURL(pageState.identifier, pageState.status, parseInt(pageState.pageNumber) + 1, pageState.per_page);
    }
  }
  
  function prevPage() {
    if(parseInt(pageState.pageNumber) > 1) {
      setURL(pageState.identifier, pageState.status, parseInt(pageState.pageNumber) - 1, pageState.per_page);
    }
  }

  const TableContainer = styled.div`
    height: 100%;
  `

  const queryIdentifier = searchParams.get('identifier');
  const queryStatus = searchParams.get('status');
  const queryPage = searchParams.get('page');
  const queryPerPage = searchParams.get('per_page');

  const newPageState = { ...pageState }

  if (
    (queryIdentifier != pageState.identifier) ||
    (queryStatus != pageState.status) ||
    (parseInt(queryPage) != pageState.pageNumber) ||
    (queryPerPage != pageState.per_page)
  ) {

    if (queryIdentifier != pageState.identifier) { 
      // console.log("changing identifier from " + pageState.identifier + " to " + queryIdentifier);
      // setFilteredResources(resources.filter((resource) => resource.identifier === queryIdentifier)); 
      newPageState.identifier = queryIdentifier;
    }
    if (queryStatus != pageState.status) {
      // console.log("changing status from " + pageState.status + " to " + queryStatus);
      // setFilteredResources(filteredResources.filter((resource) => resource.status === queryStatus)); 
      newPageState.status = queryStatus;
    }
    if (queryPage != pageState.pageNumber) { 
      // console.log("changing page number from " + pageState.pageNumber + " to " + queryPage);
      newPageState.pageNumber = queryPage;
    } else if (newPageState.identifier != pageState.identifier || newPageState.status != pageState.status) {
      // Move to page 1 if a filter param was updated and the page isn't specified
      newPageState.pageNumber = 1;
    }
    if (queryPerPage != pageState.per_page) {
      newPageState.per_page = queryPerPage;
    }
    setPageState(newPageState);
  }

  return (
    <div>
      <SearchBar 
        filterChoices={filterChoices}
        filterDefault={pageState.status}
        searchDefault={pageState.identifier}
        perPageDefault={pageState.per_page}
        onSearch={handleIdentifierSearch}
        onFilter={handleStatusFilter}
        onPerPageSet={handlePerPageSet}
      />
      <label className='ps-3 mt-5'>{((pageState.pageNumber - 1) * pageState.per_page + 1) + ' - ' + ((pageState.pageNumber - 1) * pageState.per_page + filteredResources.length) + ' of ' + filteredResources.length}</label>
      <button onClick={prevPage}>prev</button>
      <button onClick={nextPage}>next</button>
      <TableContainer className='mt-3'>
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
              <th>Created At</th>
              <th>Updated At</th>
            </tr>
          </thead>
          <tbody className=''>
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
                <td>{resource.created_at}</td>
                <td>{resource.updated_at}</td>
              </tr>
            )}
          </tbody>
        </table>
        {/* <ol>{resources.map((resource) => <li key={resource.identifier}>{JSON.stringify(resource)}</li>)}</ol> */}
      </TableContainer>
      <label className='ps-3 mt-1'>{((pageState.pageNumber - 1) * pageState.per_page + 1) + ' - ' + ((pageState.pageNumber - 1) * pageState.per_page + filteredResources.length) + ' of ' + filteredResources.length}</label>
      <button onClick={prevPage}>prev</button>
      <button onClick={nextPage}>next</button>
    </div>
  );
}