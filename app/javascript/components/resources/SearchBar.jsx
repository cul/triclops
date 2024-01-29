import React, {useRef} from 'react';

export default function SearchBar({onSearch}) {
  const filterInput = useRef();

  return (
    <div>
      <t>filter by: </t>
      <input ref={filterInput}/>
      <t> </t>
      <button onClick={() => onSearch(filterInput.current.value)}>search</button>
    </div>
  )
}