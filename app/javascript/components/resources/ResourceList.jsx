import React, { useEffect, useState } from 'react';
import styled from 'styled-components';

export default function ResourceList() {
  const [resources, setResources] = useState([]);
  useEffect(() => {
    (async () => {
      const response = await fetch(
        '/api/v1/resources',
        {
          headers: {
            // 'Authorization': 'Token changethis'
          }
        });
      const data = await response.json();
      setResources(data);
    })();
    
  }, []);

  const TableContainer = styled.div`
    height: 100%;
  `

  return (
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
          {resources.map((resource) => 
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
  );
}