import React, {useRef} from 'react';

// const STATUSES = [1, 2, 3, 4];

export default function SearchBar({filterChoices, filterDefault, searchDefault, perPageDefault, onSearch, onFilter, onPerPageSet}) {
  const identifierInput = useRef();
  const perPageInput = useRef();

  return (
    <div>
      <div className='input-group input-group-sm'>
      <div className='ps-3'>          <label>Filter by status: </label>
          <select name="status" value={filterDefault} onChange={(event) => {return onFilter(event.target.value)}}>
            <option key={-1} value={'Any'}>Any</option> 
            {filterChoices.map((status) => {
              return <option key={filterChoices.indexOf(status)} value={status + ''}>{status}</option>
            })}
          </select>
          <label> </label>
        </div>
        <div className='ps-3'>
          <label>Search for Identifier: </label>
          <input ref={identifierInput} defaultValue={searchDefault}/>
          <label> </label>
          <button onClick={() => onSearch(identifierInput.current.value)}>search</button>
          <label> </label>
        </div>
        <div className='ps-3'>
          <label>Results per Page: </label>
          <input ref={perPageInput} defaultValue={perPageDefault} className='w-25'/>
          <label> </label>
          <button onClick={() => onPerPageSet(perPageInput.current.value)}>set</button>
        </div>
      </div>
    </div>
  )
}